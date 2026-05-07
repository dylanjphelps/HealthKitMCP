# Luffy — History

## Project Context
- **Project:** HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via local-network MCP server
- **Stack:** Swift 5.9, iOS 18+, XcodeGen, HealthKit, WorkoutKit, MCP SDK (swift-sdk)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan

## Learnings

- 2026-05-07T14:34:34.923-05:00 — Architecture review confirmed the documented layering still holds: `MCPService` orchestrates `HealthKitMCPServer`, which dispatches thin tool handlers to `HealthKitManager` and `WorkoutKitManager` (`HealthKitMCP/MCP/MCPService.swift`, `HealthKitMCP/MCP/Server.swift`, `HealthKitMCP/MCP/Tools/`).
- 2026-05-07T14:34:34.923-05:00 — The transport reset path is concentrated in `HealthKitMCP/MCP/MCPService.swift` and `HealthKitMCP/MCP/HTTPServer.swift`; future changes there should preserve generation tracking, transport swapping, and explicit disconnect ordering together.
- 2026-05-07T14:34:34.923-05:00 — `project.yml` is the source of truth for build settings; after config edits, regenerate with `xcodegen generate` and validate with `xcodebuild test -scheme HealthKitMCP` (`project.yml`).

## Session Updates

- 2026-05-07T19:34:00Z — Codebase review session completed. Decisions archived. Team consensus documented: keep actor layering, enforce strict integer parsing, flag reconnect/reset hotspot for future refactors.
