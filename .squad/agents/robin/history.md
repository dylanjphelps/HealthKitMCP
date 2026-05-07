# Robin — History

## Project Context
- **Project:** HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via local-network MCP server
- **Stack:** Swift 5.9, iOS 18+, XcodeGen, HealthKit, WorkoutKit, MCP SDK (swift-sdk)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan

## Learnings

- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/MCP/Server.swift` owns a flat tool registry plus the `CallTool` dispatch switch; tool additions must update both list and switch together.
- 2026-05-07T14:34:34.923-05:00 — Shared MCP argument parsing helpers live in `HealthKitMCP/MCP/Tools/ToolHelpers.swift`, not beside `MCPService.swift`.
- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/MCP/MCPService.swift` is responsible for rotating `HealthKitMCPServer` instances and wiring `HTTPServer` transport resets after duplicate `initialize` requests.
- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/MCP/HTTPServer.swift` is the thin raw-socket adapter: it parses HTTP into MCP SDK `HTTPRequest` values, delegates to `StatelessHTTPServerTransport`, and writes `HTTPResponse` values back to the connection.
- 2026-05-07T15:06:17.081-05:00 — The shipped app currently advertises a LAN MCP endpoint at `http://<local-ip>:8080/mcp` from `HealthKitMCP/MCP/MCPService.swift`, intended for same-network clients rather than localhost-only desktop subprocesses.
- 2026-05-07T15:06:17.081-05:00 — `HealthKitMCP/MCP/Server.swift` currently instantiates `StatelessHTTPServerTransport` with `AcceptHeaderValidator(mode: .jsonOnly)` and disabled origin validation, so the server is POST/JSON request-response only, not full session-based Streamable HTTP.
- 2026-05-07T15:06:17.081-05:00 — `HealthKitMCP/MCP/HTTPServer.swift` already has response-writing support for streamed `.stream` responses, so moving to an SSE-capable transport would mostly be a transport-selection and validation change instead of a total socket-layer rewrite.
- 2026-05-07T15:06:17.081-05:00 — The workspace currently resolves `modelcontextprotocol/swift-sdk` to version `0.12.0` in `HealthKitMCP.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, even though `project.yml` still declares the package floor as `from: "0.1.0"`.
- 2026-05-07T15:10:12.143-05:00 — Every read/query tool currently serializes full JSON via `encodeToJSON` in `HealthKitMCP/Health/Models.swift`; the biggest token hotspots are `query_workouts` (full workout objects plus optional `splits` and `intervals`) and `query_scheduled_workouts` (nested warmup/blocks/cooldown trees).
- 2026-05-07T15:10:12.143-05:00 — Daily metric DTOs already use reasonably compact snake_case keys (`ActivitySummaryResult`, `RestingHRResult`, `HRVResult`, `BodyMassResult`, `SleepResult`), but workout/scheduled-workout payloads remain verbose enough that summary/detail or pagination options would give the largest token savings.
- 2026-05-07T15:10:12.143-05:00 — Streamable HTTP migration is centered in `HealthKitMCP/MCP/Server.swift`, `HealthKitMCP/MCP/HTTPServer.swift`, and `HealthKitMCP/MCP/MCPService.swift`: the SDK’s `StatefulHTTPServerTransport` expects `AcceptHeaderValidator(mode: .sseRequired)`, session headers, GET SSE streams, and DELETE-based session termination instead of today’s stateless POST-only flow.

## Session Updates

- 2026-05-07T19:34:00Z — MCP review session completed. Standardized tool handlers, added explicit 400 Bad Request for malformed HTTP. Team consensus documented: uniform enum shape for all tools, malformed requests return 400 at adapter layer.
- 2026-05-07T15:15:43.477-05:00 — Token shaping now lives in the MCP response layer: `HealthKitMCP/MCP/Tools/ToolHelpers.swift` parses `limit`/boolean flags and `HealthKitMCP/Health/Models.swift` owns compact envelopes, summary DTOs, and 2-decimal rounding adapters so managers can stay unchanged.
- 2026-05-07T15:15:43.477-05:00 — Array query tools under `HealthKitMCP/MCP/Tools/` now default to `limit = 50` (clamped to 500) and return `{count, limit, results}` envelopes; workout and scheduled-workout tools default to summaries unless callers opt into richer detail.
- 2026-05-07T15:15:43.477-05:00 — Streamable HTTP now uses `StatefulHTTPServerTransport` in `HealthKitMCP/MCP/Server.swift` with `AcceptHeaderValidator(mode: .sseRequired)` plus `SessionValidator()`, while `HealthKitMCP/MCP/HTTPServer.swift` remains the raw socket adapter for GET/POST/DELETE and `HealthKitMCP/MCP/MCPService.swift` only rotates servers after a session transport terminates.
- 2026-05-07T15:37:25-0500 — `StatefulHTTPServerTransport` in swift-sdk cannot be re-initialized or reset in place; `HealthKitMCP/MCP/HTTPServer.swift` must swap in a fresh `HealthKitMCPServer` transport before forwarding any new JSON-RPC `initialize` request.
