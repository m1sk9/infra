# Better Stack heartbeats (inbound pushes from s1)
#
# s1 has no port forwarding and is reachable only over Cloudflare Tunnel and
# Tailscale, so nothing outside can poll it. Every check that needs to see the
# host itself has to be inverted: s1 pushes, and Better Stack raises an incident
# when the pushes stop. The senders are systemd timers deployed by the Ansible
# `heartbeat` role; the periods below are the timer interval plus room for one
# dropped run.
#
# The ping URLs are read out of the outputs and stored in the Ansible vault by
# hand, the same way the R2 credentials are — see outputs.tf.

# s1 itself. Nothing is probed locally: arriving at all is the signal.
#
# Note what this actually measures — "s1 can reach the internet", not "s1 is
# powered on". A home line outage raises this incident with the machine perfectly
# healthy. From the outside those are the same thing, so that is the right
# reading, but it is worth knowing before chasing a phantom failure.
resource "betteruptime_heartbeat" "s1_host" {
  name   = "s1"
  period = 300 # timer fires every 2 min, so this tolerates one missed run
  grace  = 120
  email  = true
}

# Wallos' container, checked from inside s1 (see betteruptime_monitor.wallos_edge
# for the other half of this pair).
resource "betteruptime_heartbeat" "wallos" {
  name   = "wallos (origin)"
  period = 420 # timer fires every 3 min
  grace  = 180
  email  = true
}

# chime reports its container healthcheck rather than mere process liveness.
#
# Why this one is stronger than the two below: chime writes a heartbeat file on
# every scheduler tick and its `chime health` subcommand fails once that file is
# older than twice the tick interval (30s, so a 60s threshold). Reading the
# resulting Docker health status proves the scheduler is still running, not just
# that the process exists. chime posts through Discord webhooks over plain HTTP,
# so it holds no gateway connection that could rot underneath a healthy process.
resource "betteruptime_heartbeat" "chime" {
  name   = "chime"
  period = 420
  grace  = 180
  email  = true
}

# babyrite and honeypot report container liveness only.
#
# Neither image ships a healthcheck, and both hold a websocket to the Discord
# gateway. A dropped gateway connection inside a running process is therefore
# invisible here: these two say "the container is up" and nothing more. Closing
# that gap needs a push from inside the bots themselves, which lives in their own
# repositories — chime's heartbeat.rs is the worked example.
resource "betteruptime_heartbeat" "babyrite" {
  name   = "babyrite"
  period = 420
  grace  = 180
  email  = true
}

resource "betteruptime_heartbeat" "honeypot" {
  name   = "honeypot"
  period = 420
  grace  = 180
  email  = true
}

# The weekly restic backup to R2, which until now failed silently.
#
# The unit pings this on success and posts to <url>/fail with the last 50 journal
# lines when it fails, so a broken run reports immediately instead of waiting out
# the period. The period only has to catch the third case: s1 being down when the
# timer was due, so the run never happened at all.
#
# server_timezone keeps the weekly window aligned with the Friday 03:00 timer
# across DST changes. It applies only to periods of an hour or more, which is why
# the heartbeats above leave it unset. Unlike maintenance_timezone (a Rails zone
# name) this one takes an IANA name.
resource "betteruptime_heartbeat" "backup" {
  name            = "s1-backup"
  period          = 604800 # 7 days, matching OnCalendar=Fri *-*-* 03:00:00
  grace           = 21600  # 6 h
  server_timezone = "Asia/Tokyo"
  email           = true
}
