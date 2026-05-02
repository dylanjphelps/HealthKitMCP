# HealthKit MCP — iOS Design

**Date:** 2026-05-01  
**Status:** Approved

## Summary

Migrate the existing `HealthKitMCP` macOS project to an iOS app that runs a local HTTP+SSE MCP server on the iPhone. Claude Desktop on Mac connects to it over the local network. The iPhone app reads health data via HealthKit and schedules running workouts directly via WorkoutKit — no macOS HealthKit entitlement, no Shortcuts URL indirection.

## Constraints

- No paid Apple Developer account. App is sideloaded via Xcode with a free Apple ID (Personal Team). Re-signing required every 7 days (manually via Xcode, or automated via AltStore).
- iPhone app must be open when Claude queries health data or schedules a workout.
- Target: iOS 17.0+ (required for WorkoutKit scheduling APIs).

## Architecture

```
Claude Desktop (Mac)
       │  MCP HTTP+SSE  (local network)
       ▼
  iPhone App
  ├── SwiftUI UI         — server status, local address, auth buttons
  ├── HTTPSSETransport   — NWListener on port 8080, GET /sse + POST /message
  ├── HealthKitMCPServer — same Server/withMethodHandler pattern as today
  ├── HealthKitManager   — reads workouts, activity, HR, VO2 max
  └── WorkoutKitManager  — builds CustomWorkout, schedules via WorkoutScheduler
```

Claude Desktop is configured with:
```json
{
  "mcpServers": {
    "healthkit": {
      "type": "sse",
      "url": "http://[device-name].local:8080/sse"
    }
  }
}
```

The `.local` Bonjour hostname is stable across IP changes.

## Components

### HTTPSSETransport

Built on `Network.framework` (`NWListener`). No third-party HTTP libraries.

- `GET /sse` — opens a persistent SSE stream; server pushes MCP messages here
- `POST /message` — receives MCP messages from Claude Desktop
- Handles one client connection at a time (personal use tool)
- Conforms to the MCP `Transport` protocol so `Server` is unmodified

### HealthKitMCPServer

Identical structure to existing `Server.swift`. Registers tool handlers, dispatches calls. The only change is the transport passed at init.

### HealthKitManager

New file. Requests HealthKit authorization on first launch. Implements four query methods:

| Method | HealthKit type | Returns |
|---|---|---|
| `queryWorkouts(days:)` | `HKWorkout` | Array of running sessions with distance, duration, pace, avg HR, calories |
| `queryActivitySummary(days:)` | `HKActivitySummary` | Daily steps, active calories, exercise minutes |
| `queryRestingHeartRate(days:)` | `HKQuantityType(.restingHeartRate)` | Daily avg/min/max resting HR |
| `queryVO2Max()` | `HKQuantityType(.vo2Max)` | Most recent estimate with date |

All query methods are `async throws` and return JSON-encodable structs.

### WorkoutKitManager

Existing file, kept as-is for building `CustomWorkout` structures and generating descriptions.

Add one method: `schedule(_ workout: CustomWorkout, for date: Date) async throws` that calls `WorkoutScheduler().add(workout, for: date)` after requesting authorization.

### ScheduleWorkoutTool

Existing file. Remove `buildShortcutsURL` and the `shortcuts_url` / `instructions` fields from the result. Replace with a direct call to `WorkoutKitManager.schedule()`. Return JSON with `title`, `date`, `description`, and `scheduled: true`.

### SwiftUI App

Replaces `AppDelegate` + `NSWindow`. Single screen showing:

- HealthKit authorization status (authorized / not authorized) + "Grant Access" button
- WorkoutKit authorization status + "Grant Access" button
- Server status (Running / Stopped) + address label (`http://[device].local:8080`)
- Start/Stop server toggle (auto-starts on launch)

## Tools Exposed to Claude

| Tool | Parameters | Description |
|---|---|---|
| `query_workouts` | `days: Int = 7` | Running sessions — distance, pace, avg HR, calories |
| `query_activity_summary` | `days: Int = 7` | Daily steps, active calories, exercise minutes |
| `query_resting_heart_rate` | `days: Int = 7` | Daily resting HR (avg, min, max) |
| `query_vo2max` | — | Most recent VO2 max estimate |
| `schedule_workout` | `title, warmup?, blocks, cooldown?, scheduled_date?` | Schedule a structured run directly to Apple Watch |

## Data Flow

1. User opens iPhone app → app requests HealthKit + WorkoutKit authorization → starts HTTP server
2. User adds `http://[device].local:8080/sse` to Claude Desktop config, restarts Claude Desktop
3. Claude Desktop connects to `/sse` — persistent SSE stream established
4. User asks Claude about health data → Claude calls a query tool → iPhone responds with JSON
5. User asks Claude to schedule a run → Claude calls `schedule_workout` → `WorkoutScheduler` pushes workout to Apple Watch → workout appears in Fitness app

## Project Migration

**Platform target:** `macOS 15.0` → `iOS 17.0`

**Files changed:**
- `project.yml` — platform, deployment target, remove AppKit, add HealthKit entitlement
- `HealthKitMCP.entitlements` — add `com.apple.developer.healthkit`
- `Info.plist` — add `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`
- `App/AppDelegate.swift` — replace with SwiftUI `@main` struct + `ContentView`
- `App/main.swift` — delete (conflicts with `@main`)
- `MCP/Server.swift` — swap `StdioTransport` → `HTTPSSETransport`
- `MCP/Tools/ScheduleWorkoutTool.swift` — remove Shortcuts URL, add `WorkoutKitManager.schedule()` call

**Files added:**
- `App/ContentView.swift` — SwiftUI status screen
- `MCP/Transport/HTTPSSETransport.swift` — `NWListener`-based HTTP+SSE transport
- `Health/HealthKitManager.swift` — four query methods

**Files unchanged:**
- `Health/WorkoutKitManager.swift` (add `schedule` method only)
- `Health/Models.swift`
- `MCP/Tools/` — all other tool files (none today, new query tools go here)

## Setup (End-to-End)

1. Open `HealthKitMCP.xcodeproj` in Xcode, select your iPhone as the run destination
2. Set Signing team to your personal Apple ID team
3. Build and run (`Cmd+R`) — app installs to iPhone
4. In the app: tap "Grant Access" for HealthKit and WorkoutKit
5. Note the address shown (e.g. `http://Dylans-iPhone.local:8080`)
6. Add to `~/Library/Application Support/Claude/claude_desktop_config.json` and restart Claude Desktop
7. Re-sign every 7 days: reconnect iPhone, hit `Cmd+R` in Xcode (or use AltStore for automatic renewal)
