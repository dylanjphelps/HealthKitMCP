# Workout Splits & Intervals Design

**Date:** 2026-05-03

## Goal

Expose per-mile split data and per-interval data from running workouts so the LLM can analyse pacing, consistency, and structured workout execution.

## Approach

Embed splits and intervals directly in `WorkoutResult`. All data is already attached to the `HKWorkout` object returned by the existing sample query — no additional HealthKit queries are needed.

## Data Model

### New structs in `Models.swift`

```swift
struct SplitResult: Codable {
    let mile: Int                    // 1-based mile number
    let pace_sec_per_mile: Double    // time to cover this mile, in seconds
    let elapsed_seconds: Double      // cumulative time from workout start at end of split
}

struct IntervalResult: Codable {
    let index: Int                   // 0-based position in workout
    let type: String                 // "work" | "recovery" | "warmup" | "cooldown" | "lap"
    let duration_seconds: Double
    let distance_miles: Double?
    let pace_sec_per_mile: Double?
    let avg_heart_rate_bpm: Double?
}
```

### Changes to `WorkoutResult` in `Models.swift`

Add two new optional fields:

```swift
let splits: [SplitResult]?
let intervals: [IntervalResult]?
```

Both are `nil` when no data is available (e.g. treadmill run with no GPS, free run with no structured workout and no manual laps).

## Implementation

All changes are inside `HealthKitManager.queryWorkouts`, in the `.map { w -> WorkoutResult in }` closure.

### Splits — `w.workoutEvents` filtered for `.segment`

- Events are ordered chronologically; each represents one completed mile.
- Pace for each full mile = `segment.dateInterval.duration` (seconds per mile).
- The last segment is partial: `remaining = total_distance - floor(total_distance)`. Pace = `duration / remaining`. Skip if `remaining < 0.05` miles to avoid noise from sub-segment slivers at workout end.
- `elapsed_seconds` = `segment.dateInterval.end.timeIntervalSince(w.startDate)`.
- Result is `nil` (not empty array) if no segment events exist.

### Intervals — `w.workoutActivities` + `.lap` fallback

**Structured workouts (WorkoutKit-planned):**
- Use `w.workoutActivities` (available iOS 16+, this app targets iOS 18+).
- Each `HKWorkoutActivity` maps to one entry:
  - `duration` = `activity.duration`
  - `distance_miles` from `activity.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()`
  - `pace_sec_per_mile` = `duration / distance_miles` (nil if distance is nil or zero)
  - `avg_heart_rate_bpm` from `activity.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()`
  - `type` derived from `activity.workoutConfiguration.activityType`:
    - `.cooldown` → `"cooldown"`, `.preparationAndRecovery` → `"recovery"`, `.running` → `"run"`, `.walking` → `"walk"`, any other → `"segment"`
    - Note: the first activity in a WorkoutKit workout corresponds to warmup, last to cooldown — but since `activityType` is the authoritative source, use it directly rather than inferring from position.

**Manual laps (free runs):**
- If `w.workoutActivities` is empty, fall back to `w.workoutEvents` filtered for `.lap`.
- Each lap event: `duration` = `event.dateInterval.duration`, `type` = `"lap"`. Distance and HR are not available from lap events alone — set to `nil`.
- Result is `nil` (not empty array) if neither source has data.

## Authorization

`HKWorkoutActivity.statistics(for:)` uses `heartRate` and `distanceWalkingRunning` — both already in the authorized set. No new authorization entries needed.

## Files Changed

| File | Change |
|------|--------|
| `HealthKitMCP/Health/Models.swift` | Add `SplitResult`, `IntervalResult` structs; add `splits` and `intervals` fields to `WorkoutResult` |
| `HealthKitMCP/Health/HealthKitManager.swift` | Compute splits and intervals inside existing map closure in `queryWorkouts` |

## Out of Scope

- HR per mile split (requires separate `HKStatisticsCollectionQuery` per workout — too expensive for bulk queries)
- Kilometre splits (miles only, consistent with rest of codebase)
- Pace per lap for manual-lap fallback (not derivable without route data)
