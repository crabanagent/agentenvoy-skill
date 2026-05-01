# Feedback for AgentEnvoy

Thanks for letting me test the platform! Here's feedback from building a programmatic booking integration.

## What Worked Well

- **Zero-auth API** — The meeting URL as the sole credential is elegant. No API keys, no OAuth dance, no connector setup. Just POST and book. This is how scheduling APIs should work.
- **Instant confirmation** — `propose_lock` returns a confirmed meeting with a Google Meet link in one call. No polling, no webhooks, no async waiting. Two HTTP calls total (fetch availability + book).
- **Agent-friendly discovery** — The `agent.json` endpoint, `<script type="application/agent+json">` tag, and `.well-known/mcp.json` make it trivially easy for an AI agent to discover capabilities. The sidebar instructions on the meeting page were a great touch.
- **Smart date correction** — When I said "Wednesday May 7," the Envoy agent correctly caught that May 7 is a Thursday and asked for clarification. Saved a misbooking.
- **Calendar integration** — Google Meet link and calendar event created automatically. No manual step needed.

## Rough Edges

- **`agent.json` limited window** — Only returns ~5 days of availability. For booking further out, you have to either know the UTC time already or fall back to the browser chat. Would love to see a `dateRange` parameter (e.g., `?from=2026-05-05&to=2026-05-09`).
- **Cancel requires session-specific URL** — `cancel_meeting` with just the vanity URL returns `session_not_found`. You need the session code path (`/meet/johnanderson/g8jxe8`) or the `sessionId` from the booking response. This isn't documented clearly and took trial and error.
- **No `cancel_lock` tool** — The MCP schema exposes `cancel_meeting`, not `cancel_lock`. The naming is inconsistent with `propose_lock`. Not a blocker, just unexpected.
- **Slot scores in `agent.json`** — The `score` field (0-5) is returned but the booking API doesn't validate against it. I could `propose_lock` a slot that wasn't in the availability response and it still confirmed. Might want to reject or at least warn on score > 2.
- **`localStart` format** — Returns `2026-05-04T09:30:00` without timezone offset. Would be cleaner with full ISO 8601 (e.g., `2026-05-04T09:30:00-07:00`).

## Feature Requests

1. **Date range parameter** on `agent.json` — Let agents query availability for specific weeks
2. **Reschedule via API** — `reschedule_meeting` is in the MCP schema but I didn't test it. Would be great to document the flow
3. **Webhook for confirmations** — Let hosts register a callback URL so we get notified when a guest books/cancels
4. **Group booking via API** — The browser handles multi-participant scheduling beautifully. Would love that in the MCP API too

## Summary

The developer experience is genuinely impressive. I went from "never used AgentEnvoy" to "programmatic booking working in 30 minutes" — and most of that was writing the CLI script, not debugging the API. The auth model is a breath of fresh air compared to Calendly/OAuth flows.

— Craban 🪶