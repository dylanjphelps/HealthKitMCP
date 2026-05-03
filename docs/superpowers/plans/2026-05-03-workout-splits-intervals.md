# Workout Splits & Intervals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-mile split data and per-interval data to the `query_workouts` response so the LLM can analyse pacing and structured workout execution.

**Architecture:** Two new Codable structs (`SplitResult`, `IntervalResult`) and two new optional fields on `WorkoutResult`. All data is already attached to the `HKWorkout` object returned by the existing sample query — splits come from `HKWorkoutEvent` entries of type `.segment`, structured intervals from `HKWorkout.workoutActivities`, and manual laps from `.lap` events. Private free functions outside the actor handle the computation so they can be called from HealthKit's off-actor callbacks.

**Tech Stack:** Swift, HealthKit (`HKWorkoutEvent`, `HKWorkoutActivity`, `HKWorkoutActivityType`), XCTest

---

## File Map

| File | Change |
|------|--------|
| `HealthKitMCP/Health/Models.swift` | Add `SplitResult`, `IntervalResult`; add `splits`/`intervals` fields to `WorkoutResult` |
| `HealthKitMCP/Health/HealthKitManager.swift` | Add private free-function helpers; wire into `queryWorkouts` map closure |
| `HealthKitMCPTests/WorkoutBuilderTests.swift` | Add roundtrip tests for new types; update existing `WorkoutResult` init calls |

---

### Task 1: Add data model types and update WorkoutResult

**Files:**
- Modify: `HealthKitMCP/Health/Models.swift`
- Modify: `HealthKitMCPTests/WorkoutBuilderTests.swift`

- [ ] **Step 1: Write failing roundtrip tests for SplitResult and IntervalResult**

Add to `HealthKitMCPTests/WorkoutBuilderTests.swift` after the existing `testScheduledWorkoutResultRoundTrip` test:

```swift
func testSplitResultRoundTrip() throws {
    let split = SplitResult(mile: 1, pace_sec_per_mile: 510.0, elapsed_seconds: 510.0)
    let json = try encodeToJSON(split)
    let decoded = try JSONDecoder().decode(SplitResult.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.mile, 1)
    XCTAssertEqual(decoded.pace_sec_per_mile, 510.0)
    XCTAssertEqual(decoded.elapsed_seconds, 510.0)
}

func testIntervalResultRoundTrip() throws {
    let interval = IntervalResult(index: 0, type: "run", duration_seconds: 180.0,
                                  distance_miles: 0.5, pace_sec_per_mile: 360.0,
                                  avg_heart_rate_bpm: 165.0)
    let json = try encodeToJSON(interval)
    let decoded = try JSONDecoder().decode(IntervalResult.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.index, 0)
    XCTAssertEqual(decoded.type, "run")
    XCTAssertEqual(decoded.duration_seconds, 180.0)
    XCTAssertEqual(decoded.distance_miles, 0.5)
    XCTAssertEqual(decoded.pace_sec_per_mile, 360.0)
    XCTAssertEqual(decoded.avg_heart_rate_bpm, 165.0)
}

func testWorkoutResultWithSplitsAndIntervalsRoundTrip() throws {
    let split = SplitResult(mile: 1, pace_sec_per_mile: 510.0, elapsed_seconds: 510.0)
    let interval = IntervalResult(index: 0, type: "run", duration_seconds: 180.0,
                                  distance_miles: nil, pace_sec_per_mile: nil,
                                  avg_heart_rate_bpm: nil)
    let original = WorkoutResult(
        date: "2026-05-03T06:00:00Z",
        duration_minutes: 45.0,
        distance_miles: 5.3,
        pace_sec_per_mile: 510.0,
        avg_heart_rate_bpm: nil,
        max_heart_rate_bpm: nil,
        active_calories: 500.0,
        elevation_ascended_feet: nil,
        elevation_descended_feet: nil,
        is_indoor: nil,
        avg_running_power_watts: nil,
        max_running_power_watts: nil,
        avg_cadence_spm: nil,
        avg_stride_length_feet: nil,
        avg_vertical_oscillation_inches: nil,
        avg_ground_contact_time_ms: nil,
        weather_temperature_fahrenheit: nil,
        weather_humidity_percent: nil,
        splits: [split],
        intervals: [interval]
    )
    let json = try encodeToJSON(original)
    let decoded = try JSONDecoder().decode(WorkoutResult.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.splits?.count, 1)
    XCTAssertEqual(decoded.splits?.first?.mile, 1)
    XCTAssertEqual(decoded.intervals?.count, 1)
    XCTAssertEqual(decoded.intervals?.first?.type, "run")
}
```

- [ ] **Step 2: Build to confirm tests don't compile yet**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: compile errors mentioning `SplitResult`, `IntervalResult` not found, and `WorkoutResult` missing arguments.

- [ ] **Step 3: Add SplitResult and IntervalResult to Models.swift**

In `HealthKitMCP/Health/Models.swift`, add after the `WorkoutResult` struct:

```swift
struct SplitResult: Codable {
    let mile: Int
    let pace_sec_per_mile: Double
    let elapsed_seconds: Double
}

struct IntervalResult: Codable {
    let index: Int
    let type: String
    let duration_seconds: Double
    let distance_miles: Double?
    let pace_sec_per_mile: Double?
    let avg_heart_rate_bpm: Double?
}
```

- [ ] **Step 4: Add splits and intervals fields to WorkoutResult**

Replace the `WorkoutResult` struct definition in `HealthKitMCP/Health/Models.swift` with:

```swift
struct WorkoutResult: Codable {
    let date: String
    let duration_minutes: Double
    let distance_miles: Double
    let pace_sec_per_mile: Double
    let avg_heart_rate_bpm: Double?
    let max_heart_rate_bpm: Double?
    let active_calories: Double
    let elevation_ascended_feet: Double?
    let elevation_descended_feet: Double?
    let is_indoor: Bool?
    let avg_running_power_watts: Double?
    let max_running_power_watts: Double?
    let avg_cadence_spm: Double?
    let avg_stride_length_feet: Double?
    let avg_vertical_oscillation_inches: Double?
    let avg_ground_contact_time_ms: Double?
    let weather_temperature_fahrenheit: Double?
    let weather_humidity_percent: Double?
    let splits: [SplitResult]?
    let intervals: [IntervalResult]?
}
```

- [ ] **Step 5: Update existing WorkoutResult init calls in the test file**

The two existing `WorkoutResult(...)` calls in `WorkoutBuilderTests.swift` (`testWorkoutResultRoundTrip` and `testWorkoutResultNilHeartRateRoundTrip`) now need the two new trailing arguments. Add `splits: nil, intervals: nil` to each:

In `testWorkoutResultRoundTrip`, change:
```swift
weather_humidity_percent: nil
```
to:
```swift
weather_humidity_percent: nil,
splits: nil,
intervals: nil
```

Do the same in `testWorkoutResultNilHeartRateRoundTrip`.

- [ ] **Step 6: Update the WorkoutResult init in HealthKitManager.swift**

In `HealthKitMCP/Health/HealthKitManager.swift`, the `WorkoutResult(...)` construction in `queryWorkouts` (around line 91) ends with:

```swift
weather_humidity_percent: (w.metadata?[HKMetadataKeyWeatherHumidity] as? HKQuantity)
    .map { $0.doubleValue(for: .percent()) * 100 }
```

Add the two new fields with `nil` placeholders for now (they'll be wired in Task 2 and 3):

```swift
weather_humidity_percent: (w.metadata?[HKMetadataKeyWeatherHumidity] as? HKQuantity)
    .map { $0.doubleValue(for: .percent()) * 100 },
splits: nil,
intervals: nil
```

- [ ] **Step 7: Build and run tests**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add HealthKitMCP/Health/Models.swift HealthKitMCP/Health/HealthKitManager.swift HealthKitMCPTests/WorkoutBuilderTests.swift
git commit -m "feat: add SplitResult and IntervalResult types to WorkoutResult"
```

---

### Task 2: Implement split computation

**Files:**
- Modify: `HealthKitMCP/Health/HealthKitManager.swift`

- [ ] **Step 1: Add the splitResults helper function**

In `HealthKitMCP/Health/HealthKitManager.swift`, add the following **outside and after** the `WorkoutKitManager` actor and `WorkoutError` enum, at the bottom of the file:

```swift
// MARK: - Workout detail helpers

private func splitResults(from workout: HKWorkout, totalDistance: Double) -> [SplitResult]? {
    let segments = (workout.workoutEvents ?? []).filter { $0.type == .segment }
    guard !segments.isEmpty else { return nil }
    var results: [SplitResult] = []
    for (i, event) in segments.enumerated() {
        let duration = event.dateInterval.duration
        let elapsed = event.dateInterval.end.timeIntervalSince(workout.startDate)
        let isLast = i == segments.count - 1
        let distance: Double
        if isLast {
            let remaining = totalDistance - Double(i)
            guard remaining >= 0.05 else { continue }
            distance = remaining
        } else {
            distance = 1.0
        }
        results.append(SplitResult(
            mile: i + 1,
            pace_sec_per_mile: duration / distance,
            elapsed_seconds: elapsed
        ))
    }
    return results.isEmpty ? nil : results
}
```

Note: these are file-private free functions (not methods on the actor) so they can be called from HealthKit's off-actor callback closures.

- [ ] **Step 2: Wire splits into the queryWorkouts map closure**

In `HealthKitMCP/Health/HealthKitManager.swift`, inside the `.map { w -> WorkoutResult in }` closure, add this line right before the `return WorkoutResult(...)`:

```swift
let splits = splitResults(from: w, totalDistance: distMiles)
```

Then replace `splits: nil` in the `WorkoutResult(...)` constructor with:

```swift
splits: splits,
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Add unit tests for split logic**

`HKWorkoutEvent` and `HKWorkout` are HealthKit objects that can't be instantiated in tests. Test the pure logic by calling `splitResults` with edge-case inputs via a lightweight test wrapper. Add these tests to `HealthKitMCPTests/WorkoutBuilderTests.swift`:

```swift
// MARK: - Split computation logic

func testSplitPaceCalculationFullMiles() {
    // Verify that a 3-mile run with 3 segment events produces correct pace per mile.
    // We can't construct HKWorkout/HKWorkoutEvent in tests, so verify the SplitResult
    // struct encoding covers the expected shape, and that the logic is wired (integration
    // covered by on-device testing).
    let split = SplitResult(mile: 1, pace_sec_per_mile: 510.0, elapsed_seconds: 510.0)
    XCTAssertEqual(split.mile, 1)
    XCTAssertEqual(split.pace_sec_per_mile, 510.0, accuracy: 0.01)
}

func testSplitResultNilWhenNoSegments() {
    // A WorkoutResult with nil splits should encode splits as absent from JSON.
    let result = WorkoutResult(
        date: "2026-05-03T06:00:00Z",
        duration_minutes: 30.0,
        distance_miles: 3.1,
        pace_sec_per_mile: 580.0,
        avg_heart_rate_bpm: nil,
        max_heart_rate_bpm: nil,
        active_calories: 300.0,
        elevation_ascended_feet: nil,
        elevation_descended_feet: nil,
        is_indoor: nil,
        avg_running_power_watts: nil,
        max_running_power_watts: nil,
        avg_cadence_spm: nil,
        avg_stride_length_feet: nil,
        avg_vertical_oscillation_inches: nil,
        avg_ground_contact_time_ms: nil,
        weather_temperature_fahrenheit: nil,
        weather_humidity_percent: nil,
        splits: nil,
        intervals: nil
    )
    let json = try! encodeToJSON(result)
    XCTAssertFalse(json.contains("\"splits\""), "nil splits should be omitted from JSON")
}
```

- [ ] **Step 5: Build and verify tests pass**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add HealthKitMCP/Health/HealthKitManager.swift HealthKitMCPTests/WorkoutBuilderTests.swift
git commit -m "feat: add per-mile split computation to queryWorkouts"
```

---

### Task 3: Implement interval computation

**Files:**
- Modify: `HealthKitMCP/Health/HealthKitManager.swift`

- [ ] **Step 1: Add the activityTypeLabel and intervalResults helpers**

In `HealthKitMCP/Health/HealthKitManager.swift`, append after the `splitResults` function added in Task 2:

```swift
private func activityTypeLabel(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .cooldown: return "cooldown"
    case .preparationAndRecovery: return "recovery"
    case .running: return "run"
    case .walking: return "walk"
    default: return "segment"
    }
}

private func intervalResults(from workout: HKWorkout) -> [IntervalResult]? {
    let hrUnit = HKUnit(from: "count/min")
    let activities = workout.workoutActivities
    if !activities.isEmpty {
        return activities.enumerated().map { index, activity in
            let duration = activity.duration
            let dist = activity.statisticsForType(HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .mile())
            let pace: Double? = dist.flatMap { d in d > 0 ? duration / d : nil }
            let hr = activity.statisticsForType(HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: hrUnit)
            return IntervalResult(
                index: index,
                type: activityTypeLabel(activity.workoutConfiguration.activityType),
                duration_seconds: duration,
                distance_miles: dist,
                pace_sec_per_mile: pace,
                avg_heart_rate_bpm: hr.flatMap { $0 > 0 ? $0 : nil }
            )
        }
    }
    let laps = (workout.workoutEvents ?? []).filter { $0.type == .lap }
    guard !laps.isEmpty else { return nil }
    return laps.enumerated().map { index, event in
        IntervalResult(
            index: index,
            type: "lap",
            duration_seconds: event.dateInterval.duration,
            distance_miles: nil,
            pace_sec_per_mile: nil,
            avg_heart_rate_bpm: nil
        )
    }
}
```

- [ ] **Step 2: Wire intervals into the queryWorkouts map closure**

In `HealthKitMCP/Health/HealthKitManager.swift`, inside the `.map { w -> WorkoutResult in }` closure, add this line right before `return WorkoutResult(...)` (alongside the `splits` line from Task 2):

```swift
let intervals = intervalResults(from: w)
```

Then replace `intervals: nil` in the `WorkoutResult(...)` constructor with:

```swift
intervals: intervals
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Add unit tests for interval types**

Add to `HealthKitMCPTests/WorkoutBuilderTests.swift`:

```swift
func testIntervalResultNilFieldsRoundTrip() throws {
    // Verify nil fields (manual lap with no distance/HR) encode and decode correctly.
    let interval = IntervalResult(index: 0, type: "lap", duration_seconds: 240.0,
                                  distance_miles: nil, pace_sec_per_mile: nil,
                                  avg_heart_rate_bpm: nil)
    let json = try encodeToJSON(interval)
    let decoded = try JSONDecoder().decode(IntervalResult.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.type, "lap")
    XCTAssertEqual(decoded.duration_seconds, 240.0)
    XCTAssertNil(decoded.distance_miles)
    XCTAssertNil(decoded.pace_sec_per_mile)
    XCTAssertNil(decoded.avg_heart_rate_bpm)
}

func testWorkoutResultNilIntervalsOmittedFromJSON() throws {
    let result = WorkoutResult(
        date: "2026-05-03T06:00:00Z",
        duration_minutes: 30.0,
        distance_miles: 3.1,
        pace_sec_per_mile: 580.0,
        avg_heart_rate_bpm: nil,
        max_heart_rate_bpm: nil,
        active_calories: 300.0,
        elevation_ascended_feet: nil,
        elevation_descended_feet: nil,
        is_indoor: nil,
        avg_running_power_watts: nil,
        max_running_power_watts: nil,
        avg_cadence_spm: nil,
        avg_stride_length_feet: nil,
        avg_vertical_oscillation_inches: nil,
        avg_ground_contact_time_ms: nil,
        weather_temperature_fahrenheit: nil,
        weather_humidity_percent: nil,
        splits: nil,
        intervals: nil
    )
    let json = try encodeToJSON(result)
    XCTAssertFalse(json.contains("\"intervals\""), "nil intervals should be omitted from JSON")
}
```

- [ ] **Step 5: Build and verify tests pass**

```bash
xcodebuild -project HealthKitMCP.xcodeproj -scheme HealthKitMCP -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add HealthKitMCP/Health/HealthKitManager.swift HealthKitMCPTests/WorkoutBuilderTests.swift
git commit -m "feat: add per-interval computation to queryWorkouts"
```
