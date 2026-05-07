# Usopp — History

## Project Context
- **Project:** HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via local-network MCP server
- **Stack:** Swift 5.9, iOS 18+, XcodeGen, HealthKit, WorkoutKit, MCP SDK (swift-sdk)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan

## Learnings

- 2026-05-07T14:34:34.923-05:00 — Strengthened parser coverage in `HealthKitMCPTests/HTTPParserTests.swift` and `HealthKitMCPTests/QueryToolParsingTests.swift` with invalid-input, default, and shape-validation cases for `HTTPServer.parseRequest`, `parseContentLength`, `parseDays`, `DeleteScheduledWorkoutTool.parseIndex`, and `ScheduleWorkoutTool.parseBlockSpec`.
- 2026-05-07T14:34:34.923-05:00 — Filled model/workout coverage gaps in `HealthKitMCPTests/WorkoutBuilderTests.swift`, especially `RestingHRResult`, `StepSpec.workoutGoal`, `WorkoutKitManager.buildCustom` validation, and warmup/cooldown description composition.

## Session Updates

- 2026-05-07T19:34:00Z — Test review session completed. Added edge-case tests for HTTP parsing, tool arg parsing, workout building, RestingHRResult, StepSpec. Fixed MCPService build-blocker. Full suite passes.
