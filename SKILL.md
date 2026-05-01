---
name: agentenvoy
description: Book meetings on AgentEnvoy (agentenvoy.ai) programmatically or via browser. Use when the user wants to schedule a meeting with someone who shares an AgentEnvoy link (e.g., agentenvoy.ai/meet/someone), check availability, or manage existing bookings. Supports listing available slots, booking time slots, and cancelling meetings via the MCP API or browser fallback.
---

# AgentEnvoy Meeting Scheduler

Book meetings through AgentEnvoy scheduling links. Two paths: fast programmatic API (preferred) or browser chat (fallback).

## Quick Start

### 1. Check Availability

```bash
skills/agentenvoy/scripts/agentenvoy.sh availability "https://agentenvoy.ai/meet/someone"
```

Or fetch the raw JSON:
```bash
curl -s 'https://agentenvoy.ai/meet/someone/agent.json' | python3 -m json.tool
```

### 2. Book a Slot

```bash
skills/agentenvoy/scripts/agentenvoy.sh book "https://agentenvoy.ai/meet/someone" "2026-05-07T21:30:00Z" "Guest Name" "guest@email.com" video
```

- **Slot start** must be UTC ISO 8601 (e.g., `2026-05-07T21:30:00Z` for 2:30 PM PDT)
- **Format**: `video` (default), `phone`, or `in-person`
- The meeting URL is the auth token — no API key needed

### 3. Cancel a Booking

```bash
skills/agentenvoy/scripts/agentenvoy.sh cancel "https://agentenvoy.ai/meet/someone" "<session_id>"
```

Session ID is returned in the booking confirmation.

## Workflow

1. **Parse the meeting URL** — User provides `agentenvoy.ai/meet/<name>` or a full URL
2. **Check availability** — Run `agentenvoy.sh availability <url>` to see open slots
3. **Confirm with user** — Present available times, let user pick
4. **Convert local time to UTC** — Use the timezone reference in `references/api.md` or calculate offset
5. **Book** — Run `agentenvoy.sh book <url> <utc_start> "<name>" <email> <format>`
6. **Report back** — Share the confirmation: date/time, Meet link, session ID

## Important Notes

- **Auth**: The meeting URL IS the credential. No API key, no OAuth. Possessing the URL = authorization.
- **Accept header**: The MCP API requires `Accept: application/json, text/event-stream` — missing this gives a 406 error.
- **Format is required**: If `agent.json` shows `guestMustResolve: true` for format, you must include it.
- **Availability window**: `agent.json` only returns ~5 days of slots. For further dates, book directly with the UTC timestamp or use the browser.
- **Score ≤ 2**: Only slots with score 0-2 are bookable. Higher scores are protected/hidden.

## Browser Fallback

If the API doesn't support what you need (e.g., slots beyond the 5-day window, negotiation with Envoy, group events), use the browser:

1. Navigate to the meeting URL
2. Chat with the Envoy agent — it understands natural language
3. Pick a time slot from the calendar widget or describe your preferred time
4. Provide name and email when asked
5. Confirm the booking

The browser path is slower but handles edge cases the API doesn't cover.

## API Details

For full endpoint documentation, error codes, and timezone conversion tables, see [references/api.md](references/api.md).