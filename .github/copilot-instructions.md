# Copilot Instructions for HealthKitMCP

## Project overview

iOS app that exposes HealthKit data to Claude Desktop via a local-network MCP (Model Context Protocol) server. The app runs on iPhone, serves an HTTP-based MCP endpoint, and Claude Desktop on the same Wi-Fi connects as a client. WorkoutKit integration allows scheduling structured running workouts to Apple Watch.

## Build and test

This project uses **XcodeGen** (`project.yml`) to generate the Xcode project. There is no `Package.swift`; the MCP SDK is declared as a package dependency in `project.yml`.

```sh
# Regenerate the Xcode project after changing project.yml
xcodegen generate

# Build (requires iOS Simulator or device destination)
xcodebuild build -scheme HealthKitMCP -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme HealthKitMCP -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -scheme HealthKitMCP -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:HealthKitMCPTests/WorkoutBuilderTests

# Run a single test method
xcodebuild test -scheme HealthKitMCP -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:HealthKitMCPTests/WorkoutBuilderTests/testBasicEasyRun
```

Add `-quiet` to suppress verbose xcodebuild output.

## Architecture

```
SwiftUI App (App/, ContentView)
    └── MCPService          — orchestrator; owns server + HTTP layer, publishes UI state
         ├── HealthKitMCPServer (actor) — MCP Server, tool registry, tool dispatch
         │    ├── HealthKitManager (actor) — read-only HealthKit queries
         │    └── WorkoutKitManager (actor) — workout scheduling (WorkoutKit)
         └── HTTPServer (actor)  — NWListener + StatefulHTTPServerTransport
```

- **MCPService** (`MCP/MCPService.swift`) is the central orchestrator created as a `@StateObject` in the app entry point. It owns the MCP server and HTTP server, and publishes observable state for the UI. It manages session lifecycle and session rotation: when a new client connects while a session exists, MCPService creates a fresh `HealthKitMCPServer` and `StatefulHTTPServerTransport` pair via an `onReinitialize` callback.
- **HealthKitMCPServer** (`MCP/Server.swift`) is an `actor` that builds the MCP `Server`, registers all tools, and dispatches incoming tool calls via a `switch` on `params.name`. It has `start()` (registers handlers + starts transport) and `waitUntilDone()` (blocks until disconnect) methods.
- **HTTPServer** (`MCP/HTTPServer.swift`) is an `actor` wrapping `NWListener` with `StatefulHTTPServerTransport` for streaming HTTP (GET for SSE, POST for messages, DELETE for session teardown). The `Mcp-Session-Id` header is forwarded to the transport layer. HTTPServer delegates request handling to `transport.handleRequest()` and tracks `hasActiveSession` for client lifecycle management.
- **HealthKitManager** and **WorkoutKitManager** (`Health/`) are actors that own all HealthKit/WorkoutKit interactions. Tools never call HealthKit APIs directly.
- **Models** (`Health/Models.swift`) are plain `Codable` DTOs with `snake_case` coding keys matching JSON output.

## Adding a new MCP tool

Each tool lives in its own file under `MCP/Tools/` and follows this pattern:

1. **Create an `enum`** (not a class/struct) with `toolName`, `definition`, and `handle(...)`:
   ```swift
   enum QueryFooTool {
       static let toolName = "query_foo"
       static let definition = Tool(name: toolName, description: "...", inputSchema: ...)
       static func handle(arguments: [String: Value], healthKit: HealthKitManager) async throws -> String {
           // Parse args, call manager, return encodeToJSON(result)
       }
   }
   ```
2. **Register** the tool in `Server.swift`: add the definition to `allTools` and a `case` to the dispatch `switch`.
3. **Keep handlers thin**: parse arguments → call the appropriate manager method → encode the result with `encodeToJSON(...)`.
4. **Return string errors** for invalid/missing arguments before calling manager methods. Manager methods throw typed errors for domain failures.

Shared parsing helpers live in `ToolHelpers.swift` and are free functions or static methods for testability. Key helpers: `roundedValue()` (rounds numeric values to 2 decimal places), `parseLimit()` (enforces default limit of 50, max 500), `parseBooleanOption()` (parses opt-in detail flags).

## Token Optimization

All query tools follow a consistent token-efficiency pattern:

- **Summary by default**: Query tools return a lightweight summary (date, type, duration, distance, calories for workouts; sample count and date range for health metrics). Detailed data is opt-in via flags like `include_splits`, `include_intervals`, `include_steps`, or `include_description`.
- **Pagination**: Default limit of 50 records (max 500) with pagination on all query tools. Use `limit` and `offset` parameters to navigate results.
- **Numeric precision**: All numeric values are rounded to 2 decimal places via the `roundedValue()` helper to reduce token noise from unnecessary floating-point precision.
- **These patterns reduce typical token usage by ~70% for summary queries.**

## Conventions

- **Actors for concurrency**: all service/manager types are Swift `actor`s. The UI layer uses `@MainActor` and `@StateObject`.
- **Swift 5.9**, iOS 18.0+ deployment target.
- **MCP SDK**: imported as `MCP` from the `swift-sdk` package (`https://github.com/modelcontextprotocol/swift-sdk`).
- **Streamable HTTP**: The transport layer (`StatefulHTTPServerTransport`) handles streaming HTTP for GET (SSE), POST (messages), and DELETE (session teardown), with session state managed via `Mcp-Session-Id` headers.
- **Tests** use `@testable import HealthKitMCP` and target pure-logic helpers (parsing, building) that don't require HealthKit entitlements. Tests are small and table-style, covering defaults and edge cases.
