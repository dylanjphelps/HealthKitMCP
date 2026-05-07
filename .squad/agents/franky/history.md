# Franky — History

## Project Context
- **Project:** HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via local-network MCP server
- **Stack:** Swift 5.9, iOS 18+, XcodeGen, HealthKit, WorkoutKit, MCP SDK (swift-sdk)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan

## Learnings

- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/App/App.swift` owns a single `@StateObject` `MCPService` and injects it into `ContentView`, so SwiftUI lifecycle changes should stay centered in the app entry point instead of recreating service state in views.
- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/MCP/MCPService.swift` is `@MainActor`, refreshes HealthKit/WorkoutKit authorization state asynchronously for the UI, and coordinates MCP server replacement through `HTTPServer.setServerResetter` plus a `serverGeneration` guard.
- 2026-05-07T14:34:34.923-05:00 — `HealthKitMCP/Health/HealthKitManager.swift` keeps HealthKit queries actor-isolated and benefits from lightweight date-string helpers instead of sharing formatter instances across async query callbacks; result DTOs live in `HealthKitMCP/Health/Models.swift`.

## Session Updates

- 2026-05-07T19:34:00Z — iOS/Health review completed. Fixed SwiftUI lifecycle, auth-state refresh, Sendable DTOs, safe formatter captures, WorkoutKit enum cases. All tests passing.
