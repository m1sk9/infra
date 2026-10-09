// Leak alert: posts to Discord when a request for a secret-looking path was
// answered with 2xx, and pings a Better Stack heartbeat after every clean run.

const GRAPHQL_ENDPOINT = "https://api.cloudflare.com/client/v4/graphql";

const STEP_MS = 15 * 60 * 1000;

// Why the window trails the trigger by one step instead of ending at it: the
// adaptive datasets take a few minutes to ingest, so the newest minutes would be
// read before they are complete and never looked at again.
const INGEST_LAG_MS = STEP_MS;

const SENSITIVE_PATH_PATTERNS = [
  "%/.git/%",
  "%/.env%",
  "%wp-config%",
  "%/.aws/%",
  "%/.ssh/%",
  "%id_rsa%",
  "%/.svn/%",
  "%.sql",
  "%.bak",
  "%.zip",
  "%.tar.gz",
  "%.tgz",
  "%.7z",
];

// Why these hosts are excluded: each is a Worker that answers every path with
// the same generated body (blog's redirect page, ua's echo, working's form) and
// has no files behind it, so a 2xx there cannot be a leak. Matched as a prefix
// because the Host header sometimes carries a port (blog.m1sk9.dev:8443).
const CATCH_ALL_HOSTS = ["blog.m1sk9.dev", "ua.m1sk9.dev", "working.m1sk9.dev"];

const QUERY = `query Leaks($zoneTag: string, $filter: ZoneHttpRequestsAdaptiveGroupsFilter_InputObject!) {
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      httpRequestsAdaptiveGroups(limit: 50, orderBy: [count_DESC], filter: $filter) {
        count
        sum { edgeResponseBytes }
        dimensions {
          clientRequestHTTPHost
          clientRequestPath
          edgeResponseStatus
          edgeResponseContentTypeName
        }
      }
    }
  }
}`;

const DISCORD_CONTENT_LIMIT = 2000;

function windowFor(scheduledTime) {
  const end = Math.floor(scheduledTime / STEP_MS) * STEP_MS - INGEST_LAG_MS;
  return { start: new Date(end - STEP_MS), end: new Date(end) };
}

function filterFor({ start, end }) {
  return {
    datetime_geq: start.toISOString(),
    datetime_lt: end.toISOString(),
    requestSource: "eyeball",
    edgeResponseStatus_geq: 200,
    edgeResponseStatus_lt: 300,
    AND: [
      { OR: SENSITIVE_PATH_PATTERNS.map((p) => ({ clientRequestPath_like: p })) },
      ...CATCH_ALL_HOSTS.map((h) => ({ clientRequestHTTPHost_notlike: `${h}%` })),
    ],
  };
}

async function findLeaks(env, window) {
  const res = await fetch(GRAPHQL_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.CF_ANALYTICS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: QUERY,
      variables: { zoneTag: env.ZONE_TAG, filter: filterFor(window) },
    }),
  });
  if (!res.ok) {
    throw new Error(`GraphQL HTTP ${res.status}`);
  }
  const body = await res.json();
  if (body.errors?.length) {
    throw new Error(`GraphQL: ${body.errors.map((e) => e.message).join("; ")}`);
  }
  return body.data.viewer.zones[0].httpRequestsAdaptiveGroups;
}

function formatMessage(rows, { start, end }) {
  const header =
    `:rotating_light: **Possible leak**: ${rows.length} secret-looking path(s) answered 2xx\n` +
    `${start.toISOString()} – ${end.toISOString()}\n`;
  const lines = rows.map((r) => {
    const d = r.dimensions;
    return `- \`${d.clientRequestHTTPHost}${d.clientRequestPath}\` → ${d.edgeResponseStatus} ${d.edgeResponseContentTypeName || "-"}, ${r.count} req, ${r.sum.edgeResponseBytes} B`;
  });
  let content = header;
  for (const line of lines) {
    if (content.length + line.length + 1 > DISCORD_CONTENT_LIMIT - 20) {
      content += "- …(truncated)";
      break;
    }
    content += `${line}\n`;
  }
  return content;
}

async function postToDiscord(env, content) {
  const res = await fetch(env.DISCORD_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content, allowed_mentions: { parse: [] } }),
  });
  if (!res.ok) {
    throw new Error(`Discord webhook HTTP ${res.status}`);
  }
}

async function run(env, scheduledTime) {
  const window = windowFor(scheduledTime);
  const rows = await findLeaks(env, window);
  if (rows.length > 0) {
    await postToDiscord(env, formatMessage(rows, window));
  }
  // Why the heartbeat is sent last and only on success: a failed query or a
  // failed post must leave the heartbeat silent, so Better Stack raises the
  // incident that this Worker could not.
  const hb = await fetch(env.HEARTBEAT_URL);
  if (!hb.ok) {
    throw new Error(`heartbeat HTTP ${hb.status}`);
  }
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(run(env, event.scheduledTime));
  },
};
