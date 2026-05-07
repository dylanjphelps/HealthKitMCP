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

## Session Updates

- 2026-05-07T19:34:00Z — MCP review session completed. Standardized tool handlers, added explicit 400 Bad Request for malformed HTTP. Team consensus documented: uniform enum shape for all tools, malformed requests return 400 at adapter layer.
