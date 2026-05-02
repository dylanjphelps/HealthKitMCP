# Scheduled Workout Query & Delete — Design Spec

**Date:** 2026-05-02

## Overview

Add two MCP tools to the HealthKitMCP server: one to query all upcoming scheduled workouts, and one to delete a specific scheduled workout by index. Both use WorkoutKit's `WorkoutScheduler.shared` API.

## Architecture

Two new tool files follow the existing pattern in `MCP/Tools/`:

- `QueryScheduledWorkoutsTool.swift` — no parameters, returns a JSON array of scheduled workouts
- `DeleteScheduledWorkoutTool.swift` — takes a single `index: Int` parameter

`WorkoutKitManager` gets two new methods:

- `queryScheduled() async throws -> [ScheduledWorkoutResult]`
  Calls `WorkoutScheduler.shared.scheduledWorkouts()`, maps each `ScheduledWorkoutPlan` to a codable struct with `index`, `date` (YYYY-MM-DD string), `title`, and `type`.

- `deleteScheduled(at index: Int) async throws`
  Re-queries scheduled workouts, bounds-checks the index, and calls `scheduler.remove(_:)` on the matching item.

`Server.swift` gets two new cases in the tool dispatch switch and two entries in `allTools`.

## Data Model

New struct added to `Models.swift`:

```swift
struct ScheduledWorkoutResult: Codable {
    let index: Int
    let date: String    // YYYY-MM-DD
    let title: String   // displayName from CustomWorkout, "(unnamed)" fallback
    let type: String    // "custom", "goal", etc.
}
```

## ID Strategy

The index returned by `query_scheduled_workouts` is positional — it reflects the item's position in the array returned by `WorkoutScheduler.shared.scheduledWorkouts()`. It is only guaranteed stable for the lifetime of a single query/delete interaction. Callers should query then immediately delete.

## Error Handling

- **Authorization not determined:** request authorization via `WorkoutScheduler.shared.requestAuthorization()`; proceed if granted, throw `WorkoutError.authorizationDenied` if denied.
- **Authorization denied:** throw `WorkoutError.authorizationDenied` with a message directing the user to Settings.
- **Out-of-bounds index on delete:** throw `WorkoutError.invalidIndex("No scheduled workout at index N (found M).")` — gives the LLM enough context to re-query and retry with a valid index.
- **Unknown workout type:** `title` falls back to `"(unnamed)"`, `type` reflects the actual case name — graceful degradation, no crash.

## Tool Definitions

### `query_scheduled_workouts`
- **Parameters:** none
- **Returns:** JSON array of `ScheduledWorkoutResult`

### `delete_scheduled_workout`
- **Parameters:** `index` (integer, required) — the index from a prior `query_scheduled_workouts` call
- **Returns:** JSON confirmation with the deleted workout's date and title

## Testing

No new unit tests. The new tools follow thin-wrapper patterns identical to existing tools. Meaningful testing requires a real device or simulator with WorkoutKit; manual verification on device is sufficient.
