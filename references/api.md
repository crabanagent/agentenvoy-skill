# AgentEnvoy API Reference

## Overview

AgentEnvoy is an AI scheduling agent platform. Each host gets a personal scheduling link (e.g., `https://agentenvoy.ai/meet/johnanderson`). Guests can book meetings through:

1. **Browser chat** — interactive conversation with the host's Envoy agent
2. **MCP API** — programmatic JSON-RPC endpoint (fast, no browser needed)

The meeting URL itself serves as authentication. No API key or OAuth required.

## API Endpoints

### 1. Availability: `GET <meeting_url>/agent.json`

Returns host info, parameters, and scored slot list. Cacheable for 15 seconds.

**Example:**
```bash
curl -s 'https://agentenvoy.ai/meet/johnanderson/agent.json'
```

**Response structure:**
```json
{
  "schemaVersion": "2026-04-30",
  "meetingUrl": "https://agentenvoy.ai/meet/johnanderson",
  "host": {
    "name": "John Anderson",
    "timezone": "America/Los_Angeles"
  },
  "parameters": {
    "format": {
      "value": null,
      "origin": "unset",
      "mutability": "required",
      "allowedValues": ["video", "phone", "in-person"],
      "guestMustResolve": true
    },
    "duration": {
      "value": 30,
      "origin": "host-profile-default",
      "mutability": "host-filled"
    },
    "timezone": { "value": "America/Los_Angeles" },
    "guestMustResolve": ["format"]
  },
  "booking": {
    "endpoint": "https://agentenvoy.ai/api/mcp",
    "method": "POST",
    "tool": "propose_lock",
    "auth": "url-capability",
    "tokenParam": "meetingUrl"
  },
  "slots": [
    {
      "start": "2026-05-07T21:30:00.000Z",
      "end": "2026-05-07T22:00:00.000Z",
      "localStart": "2026-05-07T14:30:00",
      "score": 0,
      "tier": "first_offer"
    }
  ]
}
```

**Key fields:**
- `slots[].start` — UTC ISO 8601 timestamp (use this for booking)
- `slots[].localStart` — host's local time
- `slots[].score` — protection score: 0 (open) to 5 (immovable). Only score ≤ 2 is bookable.
- `slots[].tier` — availability tier: `first_offer` (best), `available`, etc.
- `parameters.format.guestMustResolve` — if true, format must be specified when booking
- `parameters.format.allowedValues` — valid format values

**Note:** `agent.json` only returns slots for the next ~5 days. For further-out dates, the MCP negotiate endpoint can query future availability, or you can book a slot directly if you know the UTC time.

### 2. Book a meeting: `POST https://agentenvoy.ai/api/mcp`

JSON-RPC call to `propose_lock`. Confirms a specific slot.

**Required headers:**
```
Content-Type: application/json
Accept: application/json, text/event-stream
```

**Important:** You MUST include both `application/json` and `text/event-stream` in Accept, or you'll get a 406 error.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "propose_lock",
    "arguments": {
      "meetingUrl": "https://agentenvoy.ai/meet/johnanderson",
      "slot": {
        "start": "2026-05-07T21:30:00Z"
      },
      "guest": {
        "name": "Bryan Schwab",
        "email": "bryan@schwab.sh"
      },
      "format": "video"
    }
  }
}
```

**Arguments:**
- `meetingUrl` (required) — The host's scheduling URL. This IS the auth token.
- `slot.start` (required) — UTC ISO 8601 timestamp for the meeting start time.
- `guest.name` (required) — Guest's full name.
- `guest.email` (required) — Guest's email (receives calendar invite).
- `format` (required if `guestMustResolve: true`) — One of: `video`, `phone`, `in-person`.

**Success response:**
```json
{
  "result": {
    "content": [{"type": "text", "text": "{...}"}],
    "structuredContent": {
      "ok": true,
      "sessionId": "cmok854hm000113il5mj3ecew",
      "status": "confirmed",
      "dateTime": "2026-05-07T21:30:00.000Z",
      "duration": 30,
      "format": "video",
      "location": null,
      "meetLink": "https://meet.google.com/vrb-ewch-zja",
      "eventLink": "https://www.google.com/calendar/event?eid=..."
    }
  }
}
```

### 3. Cancel a booking: `POST https://agentenvoy.ai/api/mcp`

JSON-RPC call to `cancel_meeting`. Deletes the GCal event and dispatches cancellation emails.

**Important:** The `meetingUrl` must include the session code (e.g., `https://agentenvoy.ai/meet/johnanderson/abc123`) when cancelling. The vanity URL alone won't find the session.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "cancel_meeting",
    "arguments": {
      "meetingUrl": "https://agentenvoy.ai/meet/johnanderson/g8jxe8",
      "sessionId": "cmok854hm000113il5mj3ecew",
      "notifyHost": true
    }
  }
}
```

**Arguments:**
- `meetingUrl` (required) — Must include the session code for cancel operations.
- `sessionId` (optional) — The session ID from the booking confirmation.
- `notifyHost` (required) — `true` to send cancellation email to the host.
- `reason` (optional) — Cancellation reason (max 1000 chars).

### 4. MCP tool schema: `GET https://agentenvoy.ai/.well-known/mcp.json`

Returns the full JSON-RPC tool schema with all available methods and their parameters.

### 5. Extended docs: `GET https://agentenvoy.ai/llms.txt`

Returns worked examples and refusal-handling patterns.

## Timezone Conversion

AgentEnvoy uses UTC for API timestamps. Convert local times to UTC:

| PDT (UTC-7) | UTC |
|---|---|
| 9:00 AM | 16:00Z |
| 10:00 AM | 17:00Z |
| 11:00 AM | 18:00Z |
| 12:00 PM | 19:00Z |
| 1:00 PM | 20:00Z |
| 2:00 PM | 21:00Z |
| 2:30 PM | 21:30Z |
| 3:00 PM | 22:00Z |
| 4:00 PM | 23:00Z |
| 5:00 PM | 00:00Z (next day) |

## Browser Fallback

If the API doesn't support an operation, the browser interface at the meeting URL provides:
- Interactive chat with the host's Envoy agent
- Calendar widget with clickable time slots
- Group event coordination
- Session management (reschedule, cancel)

The browser is also useful when:
- The slot you want isn't in the `agent.json` availability window (~5 days out)
- You need to negotiate with the Envoy agent (e.g., specify meeting topic, special requirements)
- You need to connect your own calendar for cross-referencing

## Error Handling

| HTTP Code | Meaning | Action |
|---|---|---|
| 406 | Missing `Accept: application/json, text/event-stream` | Add both content types to Accept header |
| Slot conflict | Another booking took the slot | Check availability again, pick a new slot |
| Invalid format | Format not in `allowedValues` | Check `agent.json` parameters for valid formats |