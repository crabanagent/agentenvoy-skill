#!/usr/bin/env bash
# AgentEnvoy CLI — Book meetings via AgentEnvoy MCP API
set -euo pipefail

CMD="${1:-}"
MEETING_URL="${2:-}"

usage() {
  cat <<'EOF'
AgentEnvoy CLI — Book meetings via AgentEnvoy MCP API

Usage:
  agentenvoy.sh availability <meeting_url>
      List available slots for a meeting link.

  agentenvoy.sh book <meeting_url> <iso_start_utc> <guest_name> <guest_email> [format]
      Book a specific slot. iso_start_utc is UTC ISO 8601 (e.g., 2026-05-07T21:30:00Z).
      format: video (default), phone, or in-person.

  agentenvoy.sh cancel <session_url_with_code>
      Cancel a confirmed booking. Requires the session-specific URL (found in the calendar event description).

Examples:
  agentenvoy.sh availability https://agentenvoy.ai/meet/johnanderson
  agentenvoy.sh book https://agentenvoy.ai/meet/johnanderson 2026-05-07T21:30:00Z "Bryan Schwab" bryan@schwab.sh video
  agentenvoy.sh cancel https://agentenvoy.ai/meet/johnanderson/a2tztn
EOF
  exit 1
}

[[ -z "$CMD" || -z "$MEETING_URL" ]] && usage

API_BASE="https://agentenvoy.ai/api/mcp"
AGENT_JSON_URL="${MEETING_URL%/}/agent.json"

case "$CMD" in
  availability|avail|slots)
    echo "Fetching availability from ${AGENT_JSON_URL}..." >&2
    TMPFILE=$(mktemp)
    trap "rm -f $TMPFILE" EXIT
    curl -s "$AGENT_JSON_URL" > "$TMPFILE"
    python3 - "$TMPFILE" <<'PYEOF'
import json, sys
from datetime import datetime

with open(sys.argv[1]) as f:
    data = json.load(f)

host = data.get('host', {})
print(f"Host: {host.get('name', 'Unknown')} ({host.get('timezone', 'Unknown')})")
print(f"Duration: {data.get('parameters', {}).get('duration', {}).get('value', '?')} min")
print()

params = data.get('parameters', {})
if 'format' in params:
    f = params['format']
    if f.get('mutability') == 'required' or f.get('guestMustResolve'):
        allowed = ', '.join(f.get('allowedValues', []))
        print(f'Format required: choose from [{allowed}]')
        print()

slots = data.get('slots', [])
if not slots:
    print('No slots available.')
    sys.exit(0)

by_date = {}
for s in slots:
    start = s['start']
    dt = datetime.fromisoformat(start.replace('Z', '+00:00'))
    date_str = dt.strftime('%A, %B %d')
    time_str = dt.strftime('%-I:%M %p') + ' UTC'
    local = s.get('localStart', '')
    if local:
        try:
            ldt = datetime.fromisoformat(local)
            time_str = ldt.strftime('%-I:%M %p') + ' local'
        except Exception:
            time_str = local + ' local'
    tier = s.get('tier', '')
    by_date.setdefault(date_str, []).append((time_str, tier))

for date, times in sorted(by_date.items()):
    print(f"📅 {date}")
    for t, tier in times:
        label = f"  {t}"
        if tier and tier != 'first_offer':
            label += f" ({tier})"
        print(label)
    print()
PYEOF
    ;;

  book|confirm|propose_lock)
    SLOT_START="${3:-}"
    GUEST_NAME="${4:-}"
    GUEST_EMAIL="${5:-}"
    FORMAT="${6:-video}"

    [[ -z "$SLOT_START" || -z "$GUEST_NAME" || -z "$GUEST_EMAIL" ]] && usage

    echo "Booking $SLOT_START for $GUEST_NAME <$GUEST_EMAIL>..." >&2

    PAYLOAD=$(python3 -c "
import json, sys
payload = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'tools/call',
    'params': {
        'name': 'propose_lock',
        'arguments': {
            'meetingUrl': sys.argv[1],
            'slot': {'start': sys.argv[2]},
            'guest': {'name': sys.argv[3], 'email': sys.argv[4]},
            'format': sys.argv[5]
        }
    }
}
print(json.dumps(payload))
" "$MEETING_URL" "$SLOT_START" "$GUEST_NAME" "$GUEST_EMAIL" "$FORMAT")

    TMPFILE=$(mktemp)
    trap "rm -f $TMPFILE" EXIT
    curl -s -X POST "$API_BASE" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json, text/event-stream' \
      -d "$PAYLOAD" > "$TMPFILE"

    python3 - "$TMPFILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if 'error' in data:
    err = data['error']
    print(f"❌ Error: {err.get('message', json.dumps(err))}")
    sys.exit(1)

result = data.get('result', {})
structured = result.get('structuredContent', {})
if not structured:
    for c in result.get('content', []):
        if c.get('type') == 'text':
            structured = json.loads(c['text'])
            break

if structured.get('ok'):
    status = structured.get('status', 'unknown')
    dt = structured.get('dateTime', 'unknown')
    dur = structured.get('duration', '?')
    fmt = structured.get('format', '?')
    meet = structured.get('meetLink', 'N/A')
    sid = structured.get('sessionId', 'N/A')
    print(f"✅ Booking confirmed!")
    print(f"   Status: {status}")
    print(f"   Date/Time: {dt} (UTC)")
    print(f"   Duration: {dur} min")
    print(f"   Format: {fmt}")
    print(f"   Meet Link: {meet}")
    print(f"   Session ID: {sid}")
else:
    print(f"⚠️ Unexpected response: {json.dumps(structured, indent=2)}")
PYEOF
    ;;

  cancel|cancel_lock|cancel_meeting)
    SESSION_ID="${3:-}"
    SESSION_URL="${4:-}"
    # cancel_meeting requires the session-specific URL (e.g., /meet/slug/CODE), not just the vanity URL
    # If a full session URL is provided as the 2nd arg, use it directly
    # If only vanity URL + sessionId given, we need to find the session code from calendar description
    if [[ "$MEETING_URL" == */meet/*/* ]]; then
      # Already a session-specific URL (contains the code)
      CANCEL_URL="$MEETING_URL"
    else
      # Vanity URL — check if SESSION_URL is provided as 4th arg
      if [[ -n "$SESSION_URL" ]]; then
        CANCEL_URL="$SESSION_URL"
      else
        echo "⚠️  cancel_meeting requires the session-specific URL (e.g., https://agentenvoy.ai/meet/johnanderson/abc123)" >&2
        echo "   The vanity URL alone won't work. Find the session code in the calendar event description." >&2
        echo "   Usage: agentenvoy.sh cancel <session_url_with_code>" >&2
        exit 1
      fi
    fi

    echo "Cancelling booking at ${CANCEL_URL}..." >&2

    PAYLOAD=$(python3 -c "
import json, sys
payload = {
    'jsonrpc': '2.0',
    'id': 2,
    'method': 'tools/call',
    'params': {
        'name': 'cancel_meeting',
        'arguments': {
            'meetingUrl': sys.argv[1],
            'notifyHost': True
        }
    }
}
print(json.dumps(payload))
" "$CANCEL_URL")

    TMPFILE=$(mktemp)
    trap "rm -f $TMPFILE" EXIT
    curl -s -X POST "$API_BASE" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json, text/event-stream' \
      -d "$PAYLOAD" > "$TMPFILE"

    python3 - "$TMPFILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if 'error' in data:
    err = data['error']
    print(f"❌ Error: {err.get('message', json.dumps(err))}")
    sys.exit(1)

result = data.get('result', {})
structured = result.get('structuredContent', {})
if not structured:
    for c in result.get('content', []):
        if c.get('type') == 'text':
            structured = json.loads(c['text'])
            break

if result.get('isError'):
    # MCP tool returned an error
    msgs = [c.get('text', '') for c in result.get('content', []) if c.get('type') == 'text']
    print(f"❌ Cancel failed: {'; '.join(msgs)}")
    sys.exit(1)

if structured.get('ok'):
    print(f"✅ Booking cancelled: {structured.get('sessionId', 'N/A')}")
else:
    reason = structured.get('reason', 'unknown')
    message = structured.get('message', '')
    print(f"❌ Cancel failed ({reason}): {message}")
    sys.exit(1)
PYEOF
    ;;

  *)
    usage
    ;;
esac