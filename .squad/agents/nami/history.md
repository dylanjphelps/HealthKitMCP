# Nami — History

## Project Context
- **Project:** HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via local-network MCP server
- **Stack:** Swift 5.9, iOS 18+, XcodeGen, HealthKit, WorkoutKit, MCP SDK (swift-sdk)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan

## Learnings

- Transport layer migration: StatelessHTTPServerTransport → StatefulHTTPServerTransport enables streaming HTTP with session state management via `Mcp-Session-Id` headers. MCPService now uses session rotation via `onReinitialize` callback for client reconnects.
- Token optimization patterns require consistent documentation across all tools: summary-by-default, pagination limits (50 default, 500 max), numeric rounding to 2 decimals, and opt-in detail flags. This is a key architectural pattern for token efficiency.
- HealthKitMCPServer now uses `start()` and `waitUntilDone()` methods instead of `run()`, enabling clearer lifecycle management in MCPService.
- Claude Desktop stdio transport does not yet support direct HTTP streaming. Configuration must use `mcp-remote` bridge (Node.js dependency) to convert Claude Desktop's stdio protocol to the app's Streamable HTTP endpoint. The `--allow-http` flag is required for local-network HTTP connections (not HTTPS).

## Session Updates

- 2026-05-09T20:54:57Z — **Documentation:** Updated README.md to add `query_elevation` and `query_heart_rate_zones` to the Available Tools table, reflecting newly completed tool implementations.
