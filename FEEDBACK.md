# Feedback for AgentEnvoy

Thanks for letting me test the platform! Here's feedback from building a programmatic booking integration.

## What Worked Well

- **Zero-auth API** — The meeting URL as the sole credential is elegant. No API keys, no OAuth dance, no connector setup. Just POST and book. This is how scheduling APIs should work.
- **Instant confirmation** — `propose_lock` returns a confirmed meeting with a Google Meet link in one call. No polling, no webhooks, no async waiting. Two HTTP calls total (fetch availability + book).
- **Agent-friendly discovery** — The `agent.json` endpoint, `<script type="application/agent+json">` tag, and `.well-known/mcp.json` make it trivially easy for an AI agent to discover capabilities. The sidebar instructions on the meeting page were a great touch.
- **Smart date correction** — When I said "Wednesday May 7," the Envoy agent correctly caught that May 7 is a Thursday and asked for clarification. Saved a misbooking.
- **Calendar integration** — Google Meet link and calendar event created automatically. No manual step needed.
- **Responsive fixes** — John shipped four fixes within hours of feedback: `propose_lock` now returns `meetingUrl`, `cancel_meeting` works with `sessionId` alone, `localStart` is full ISO 8601, and the agent banner is smaller. Great turnaround.

## Previously Rough Edges (Now Fixed ✅)

- ~~**Cancel required session-specific URL**~~ — Fixed: `cancel_meeting` now works with vanity URL + `sessionId`. No need to extract session codes from calendar events.
- ~~**`localStart` missing timezone offset**~~ — Fixed: Now returns full ISO 8601 with offset (e.g., `2026-05-04T09:30:00-07:00`).
- ~~**`propose_lock` didn't return session URL**~~ — Fixed: Now returns `meetingUrl` (full session URL with code) alongside `sessionId`.

## Remaining Rough Edges

- **`agent.json` limited window** — Only returns ~5 days of availability. For booking further out, you have to either know the UTC time already or fall back to the browser chat. Would love to see a `dateRange` parameter (e.g., `?from=2026-05-05&to=2026-05-09`).
- **Naming inconsistency** — The MCP schema exposes `cancel_meeting` and `propose_lock`. Different verb patterns (cancel vs propose). Not a blocker, just unexpected. Consider `book_meeting` / `cancel_meeting` or `propose_lock` / `retract_lock`.
- **Slot scores not validated on booking** — The `score` field (0-5) is returned but the booking API doesn't validate against it. I could `propose_lock` a slot that wasn't in the availability response and it still confirmed. Might want to reject or at least warn on score > 2.

## Feature Requests

1. **Date range parameter** on `agent.json` — Let agents query availability for specific weeks
2. **Reschedule via API** — `reschedule_meeting` is in the MCP schema but I didn't test it. Would be great to document the flow
3. **Webhook for confirmations** — Let hosts register a callback URL so we get notified when a guest books/cancels
4. **Group booking via API** — The browser handles multi-participant scheduling beautifully. Would love that in the MCP API too

## Summary

The developer experience is genuinely impressive. I went from "never used AgentEnvoy" to "programmatic booking working in 30 minutes" — and most of that was writing the CLI script, not debugging the API. The auth model is a breath of fresh air compared to Calendly/OAuth flows. And the same-day fixes for my feedback were outstanding.

— Craban 🪶