// 稼働時間カリキュレーター — Cloudflare Worker
// HH:MM-HH:MM の行を複数受け取り，総稼働時間を時間表記で返す。計算はクライアント側のみ。

const HTML = `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>稼働時間計算</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 640px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
  textarea { width: 100%; min-height: 160px; font-family: monospace; font-size: 1rem; padding: 0.5rem; box-sizing: border-box; }
  #total { font-size: 1.8rem; font-weight: bold; margin: 1rem 0 0.25rem; }
  #min { color: #666; font-family: monospace; }
  table { width: 100%; border-collapse: collapse; margin-top: 1rem; font-family: monospace; font-size: 0.9rem; }
  td { padding: 0.2rem 0; }
  td.dur { text-align: right; color: #666; }
  tr.bad td { color: #c00; }
  p.hint { color: #666; font-size: 0.85rem; }
</style>
</head>
<body>
  <h1>稼働時間計算</h1>
  <p class="hint">1 行 1 区間，HH:MM-HH:MM で入力。日またぎ・全角対応。</p>
  <textarea id="input" spellcheck="false">11:57-13:00
13:28-15:05
15:30-18:30
20:26-21:37</textarea>
  <div id="total">—</div>
  <div id="min"></div>
  <table id="rows"></table>

<script>
  const input = document.getElementById('input');
  const totalEl = document.getElementById('total');
  const minEl = document.getElementById('min');
  const rowsEl = document.getElementById('rows');

  function normalize(s) {
    return s.replace(/[０-９]/g, c => String.fromCharCode(c.charCodeAt(0) - 0xFEE0))
            .replace(/[：]/g, ':').replace(/[－–—~〜]/g, '-').trim();
  }
  function parseLine(raw) {
    const s = normalize(raw);
    if (!s) return { skip: true };
    const m = s.match(/^(\\d{1,2}):(\\d{2})\\s*-\\s*(\\d{1,2}):(\\d{2})$/);
    if (!m) return { error: true, raw };
    const sh=+m[1], sm=+m[2], eh=+m[3], em=+m[4];
    if (sm>59||em>59) return { error: true, raw };
    const start = sh*60+sm; let end = eh*60+em;
    if (end < start) end += 24*60;
    return { minutes: end-start, range: s };
  }
  function fmt(mins) {
    const h = Math.floor(mins/60), m = mins%60;
    if (h===0) return m+'分';
    if (m===0) return h+'時間';
    return h+'時間'+m+'分';
  }
  function esc(s){return s.replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
  function render() {
    let total=0, valid=0, rows='';
    for (const line of input.value.split('\\n')) {
      const r = parseLine(line);
      if (r.skip) continue;
      if (r.error) { rows += '<tr class="bad"><td>'+esc(r.raw.trim())+'</td><td class="dur">解析不可</td></tr>'; continue; }
      total += r.minutes; valid++;
      rows += '<tr><td>'+esc(r.range)+'</td><td class="dur">'+fmt(r.minutes)+'</td></tr>';
    }
    if (valid===0) { totalEl.textContent='—'; minEl.textContent=''; }
    else { totalEl.textContent=fmt(total); minEl.textContent='= '+total+' 分（'+valid+' 区間）'; }
    rowsEl.innerHTML = rows;
  }
  input.addEventListener('input', render);
  render();
</script>
</body>
</html>`;

export default {
  async fetch() {
    return new Response(HTML, { headers: { "content-type": "text/html; charset=utf-8" } });
  },
};
