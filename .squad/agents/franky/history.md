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
- 2026-05-07T14:50:28.085-05:00 — Updated `project.yml` target signing settings to use automatic signing with `Apple Development` and an empty `DEVELOPMENT_TEAM`, so regenerated Xcode projects keep prompting Xcode to resolve the local developer team instead of hardcoding Dylan’s personal team ID.
- 2026-05-07T14:57:36.489-05:00 — Verified `project.yml` already captures all 19 app Swift files under `HealthKitMCP/` and all 3 test Swift files under `HealthKitMCPTests/`; the missing navigator organization was from a stale generated project, and regenerating `HealthKitMCP.xcodeproj` restored the `App`, `Health`, `MCP`, and nested `MCP/Tools` groups with updated source references.

## Session Updates

- 2026-05-07T19:34:00Z — iOS/Health review completed. Fixed SwiftUI lifecycle, auth-state refresh, Sendable DTOs, safe formatter captures, WorkoutKit enum cases. All tests passing.
- 2026-05-07T19:50:00Z — Signing configuration hardened: XcodeGen-based `project.yml` regeneration workflow now preserves automatic signing without hardcoding team IDs.
