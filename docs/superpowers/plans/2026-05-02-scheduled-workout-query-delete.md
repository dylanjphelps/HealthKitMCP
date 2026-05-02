# Scheduled Workout Query & Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `query_scheduled_workouts` and `delete_scheduled_workout` MCP tools backed by WorkoutKit's `WorkoutScheduler`.

**Architecture:** Two new tool files follow the existing enum-per-tool pattern. `WorkoutKitManager` gains `queryScheduled()` and `deleteScheduled(at:)` actor methods. Both tools are wired into the existing `Server.swift` dispatch switch and `allTools` array. Index-based identification: query returns items with 0-based `index` fields; delete re-queries and removes at that position.

**Tech Stack:** Swift, WorkoutKit (`WorkoutScheduler`, `ScheduledWorkoutPlan`), MCP Swift SDK, XCTest

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `HealthKitMCP/Health/Models.swift` | Add `ScheduledWorkoutResult` struct |
| Modify | `HealthKitMCP/Health/WorkoutKitManager.swift` | Add `invalidIndex` error case, `queryScheduled()`, `deleteScheduled(at:)` |
| Create | `HealthKitMCP/MCP/Tools/QueryScheduledWorkoutsTool.swift` | Tool definition + handler |
| Create | `HealthKitMCP/MCP/Tools/DeleteScheduledWorkoutTool.swift` | Tool definition + handler |
| Modify | `HealthKitMCP/MCP/Server.swift` | Wire tool definitions and dispatch cases |
| Modify | `HealthKitMCPTests/WorkoutBuilderTests.swift` | Add model round-trip test |
| Modify | `HealthKitMCPTests/QueryToolParsingTests.swift` | Add index-parsing test |

---

## Task 1: Add `ScheduledWorkoutResult` model (TDD)

**Files:**
- Modify: `HealthKitMCPTests/WorkoutBuilderTests.swift`
- Modify: `HealthKitMCP/Health/Models.swift`

- [ ] **Step 1: Write the failing test**

Add this test to `WorkoutBuilderTests.swift` inside the `WorkoutBuilderTests` class, after the existing tests:

```swift
func testScheduledWorkoutResultRoundTrip() throws {
    let original = ScheduledWorkoutResult(index: 0, date: "2026-05-03", title: "Morning Run", type: "custom")
    let json = try encodeToJSON(original)
    let decoded = try JSONDecoder().decode(ScheduledWorkoutResult.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.index, 0)
    XCTAssertEqual(decoded.date, "2026-05-03")
    XCTAssertEqual(decoded.title, "Morning Run")
    XCTAssertEqual(decoded.type, "custom")
}
```

- [ ] **Step 2: Run test to verify it fails**

In Xcode, run the `WorkoutBuilderTests` target. Expected: compile error — `ScheduledWorkoutResult` not defined.

- [ ] **Step 3: Add struct to `Models.swift`**

Add after the `VO2MaxResult` struct:

```swift
struct ScheduledWorkoutResult: Codable {
    let index: Int
    let date: String
    let title: String
    let type: String
}
```

- [ ] **Step 4: Run test to verify it passes**

Run `WorkoutBuilderTests`. Expected: `testScheduledWorkoutResultRoundTrip` passes.

- [ ] **Step 5: Commit**

```bash
git add HealthKitMCP/Health/Models.swift HealthKitMCPTests/WorkoutBuilderTests.swift
git commit -m "feat: add ScheduledWorkoutResult model"
```

---

## Task 2: Extend `WorkoutError` with `invalidIndex`

**Files:**
- Modify: `HealthKitMCP/Health/WorkoutKitManager.swift`

- [ ] **Step 1: Add `invalidIndex` case to `WorkoutError`**

In `WorkoutKitManager.swift`, update the `WorkoutError` enum (currently at the bottom of the file). Replace:

```swift
enum WorkoutError: Error, LocalizedError {
    case invalidType(String)
    case authorizationDenied
    var errorDescription: String? {
        switch self {
        case .invalidType(let m): return m
        case .authorizationDenied:
            return "WorkoutKit access is denied. Re-enable it in Settings > Privacy & Security > Motion & Fitness, then try again."
        }
    }
}
```

With:

```swift
enum WorkoutError: Error, LocalizedError {
    case invalidType(String)
    case invalidIndex(String)
    case authorizationDenied
    var errorDescription: String? {
        switch self {
        case .invalidType(let m): return m
        case .invalidIndex(let m): return m
        case .authorizationDenied:
            return "WorkoutKit access is denied. Re-enable it in Settings > Privacy & Security > Motion & Fitness, then try again."
        }
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

Build the `HealthKitMCP` target in Xcode. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add HealthKitMCP/Health/WorkoutKitManager.swift
git commit -m "feat: add invalidIndex error case to WorkoutError"
```

---

## Task 3: Add `queryScheduled()` to `WorkoutKitManager`

**Files:**
- Modify: `HealthKitMCP/Health/WorkoutKitManager.swift`

- [ ] **Step 1: Add `queryScheduled()` method**

Add this method to the `WorkoutKitManager` actor, after the `schedule(_:for:)` method and before the closing `}` of the actor:

```swift
func queryScheduled() async throws -> [ScheduledWorkoutResult] {
    let scheduler = WorkoutScheduler.shared
    let state = await scheduler.authorizationState
    if state == .notDetermined {
        let granted = await scheduler.requestAuthorization()
        guard granted == .authorized else { throw WorkoutError.authorizationDenied }
    } else if state == .denied {
        throw WorkoutError.authorizationDenied
    }
    let plans = await scheduler.scheduledWorkouts()
    return plans.enumerated().map { index, scheduled in
        let (title, type) = workoutInfo(from: scheduled.plan)
        let date = dateString(from: scheduled.date)
        return ScheduledWorkoutResult(index: index, date: date, title: title, type: type)
    }
}

private func workoutInfo(from plan: WorkoutPlan) -> (title: String, type: String) {
    if let custom = plan.workout as? CustomWorkout {
        return (custom.displayName ?? "(unnamed)", "custom")
    }
    return ("(unnamed)", "unknown")
}

private func dateString(from components: DateComponents) -> String {
    guard let year = components.year, let month = components.month, let day = components.day else {
        return "(unknown date)"
    }
    return String(format: "%04d-%02d-%02d", year, month, day)
}
```

> **Note on `plan.workout`:** If `WorkoutPlan` does not expose a `workout` property in the installed WorkoutKit version, simplify `workoutInfo` to always return `("(unnamed)", "unknown")` and remove the `if let` cast. The `index` and `date` fields still provide enough context for deletion.

- [ ] **Step 2: Build to verify no compile errors**

Build the `HealthKitMCP` target. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add HealthKitMCP/Health/WorkoutKitManager.swift
git commit -m "feat: add queryScheduled() to WorkoutKitManager"
```

---

## Task 4: Add `deleteScheduled(at:)` to `WorkoutKitManager`

**Files:**
- Modify: `HealthKitMCP/Health/WorkoutKitManager.swift`

- [ ] **Step 1: Add `deleteScheduled(at:)` method**

Add after `queryScheduled()`, still inside the actor body:

```swift
func deleteScheduled(at index: Int) async throws -> ScheduledWorkoutResult {
    let scheduler = WorkoutScheduler.shared
    let state = await scheduler.authorizationState
    if state == .notDetermined {
        let granted = await scheduler.requestAuthorization()
        guard granted == .authorized else { throw WorkoutError.authorizationDenied }
    } else if state == .denied {
        throw WorkoutError.authorizationDenied
    }
    let plans = await scheduler.scheduledWorkouts()
    guard index >= 0 && index < plans.count else {
        throw WorkoutError.invalidIndex("No scheduled workout at index \(index) (found \(plans.count)).")
    }
    let target = plans[index]
    await scheduler.remove(target)
    let (title, type) = workoutInfo(from: target.plan)
    let date = dateString(from: target.date)
    return ScheduledWorkoutResult(index: index, date: date, title: title, type: type)
}
```

- [ ] **Step 2: Build to verify no compile errors**

Build the `HealthKitMCP` target. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add HealthKitMCP/Health/WorkoutKitManager.swift
git commit -m "feat: add deleteScheduled(at:) to WorkoutKitManager"
```

---

## Task 5: Create `QueryScheduledWorkoutsTool.swift` (TDD)

**Files:**
- Modify: `HealthKitMCPTests/QueryToolParsingTests.swift`
- Create: `HealthKitMCP/MCP/Tools/QueryScheduledWorkoutsTool.swift`

- [ ] **Step 1: Write the failing test**

Add to `QueryToolParsingTests` class in `QueryToolParsingTests.swift`:

```swift
func testQueryScheduledWorkoutsToolName() {
    XCTAssertEqual(QueryScheduledWorkoutsTool.toolName, "query_scheduled_workouts")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run `QueryToolParsingTests`. Expected: compile error — `QueryScheduledWorkoutsTool` not defined.

- [ ] **Step 3: Create the tool file**

Create `HealthKitMCP/MCP/Tools/QueryScheduledWorkoutsTool.swift`:

```swift
import Foundation
import MCP

enum QueryScheduledWorkoutsTool {
    static let toolName = "query_scheduled_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns all upcoming workouts scheduled to Apple Watch via WorkoutKit. Each item includes an index (use this to delete), date, title, and type.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static func handle(manager: WorkoutKitManager) async throws -> String {
        let results = try await manager.queryScheduled()
        return try encodeToJSON(results)
    }
}
```

- [ ] **Step 4: Add file to Xcode project**

In Xcode, right-click `MCP/Tools` group → Add Files → select `QueryScheduledWorkoutsTool.swift`. Ensure the `HealthKitMCP` target is checked.

- [ ] **Step 5: Run test to verify it passes**

Run `QueryToolParsingTests`. Expected: `testQueryScheduledWorkoutsToolName` passes.

- [ ] **Step 6: Commit**

```bash
git add HealthKitMCP/MCP/Tools/QueryScheduledWorkoutsTool.swift HealthKitMCPTests/QueryToolParsingTests.swift
git commit -m "feat: add QueryScheduledWorkoutsTool"
```

---

## Task 6: Create `DeleteScheduledWorkoutTool.swift` (TDD)

**Files:**
- Modify: `HealthKitMCPTests/QueryToolParsingTests.swift`
- Create: `HealthKitMCP/MCP/Tools/DeleteScheduledWorkoutTool.swift`

- [ ] **Step 1: Write the failing tests**

Add to `QueryToolParsingTests` class:

```swift
func testDeleteScheduledWorkoutToolName() {
    XCTAssertEqual(DeleteScheduledWorkoutTool.toolName, "delete_scheduled_workout")
}

func testDeleteScheduledWorkoutParseIndex() {
    XCTAssertEqual(DeleteScheduledWorkoutTool.parseIndex(from: ["index": .int(2)]), 2)
}

func testDeleteScheduledWorkoutParseIndexMissing() {
    XCTAssertNil(DeleteScheduledWorkoutTool.parseIndex(from: [:]))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run `QueryToolParsingTests`. Expected: compile error — `DeleteScheduledWorkoutTool` not defined.

- [ ] **Step 3: Create the tool file**

Create `HealthKitMCP/MCP/Tools/DeleteScheduledWorkoutTool.swift`:

```swift
import Foundation
import MCP

enum DeleteScheduledWorkoutTool {
    static let toolName = "delete_scheduled_workout"

    static let definition = Tool(
        name: toolName,
        description: "Deletes a scheduled workout from Apple Watch by its index. Call query_scheduled_workouts first to get the index.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "index": .object([
                    "type": .string("integer"),
                    "description": .string("The index of the workout to delete, from query_scheduled_workouts.")
                ])
            ]),
            "required": .array([.string("index")])
        ])
    )

    static func parseIndex(from args: [String: Value]) -> Int? {
        args["index"]?.intValue
    }

    static func handle(args: [String: Value], manager: WorkoutKitManager) async throws -> String {
        guard let index = parseIndex(from: args) else {
            return "Missing required parameter: index"
        }
        let deleted = try await manager.deleteScheduled(at: index)
        return try encodeToJSON(deleted)
    }
}
```

- [ ] **Step 4: Add file to Xcode project**

In Xcode, right-click `MCP/Tools` group → Add Files → select `DeleteScheduledWorkoutTool.swift`. Ensure the `HealthKitMCP` target is checked.

- [ ] **Step 5: Run tests to verify they pass**

Run `QueryToolParsingTests`. Expected: all three new tests pass.

- [ ] **Step 6: Commit**

```bash
git add HealthKitMCP/MCP/Tools/DeleteScheduledWorkoutTool.swift HealthKitMCPTests/QueryToolParsingTests.swift
git commit -m "feat: add DeleteScheduledWorkoutTool"
```

---

## Task 7: Wire tools into `Server.swift`

**Files:**
- Modify: `HealthKitMCP/MCP/Server.swift`

- [ ] **Step 1: Add tool definitions to `allTools`**

In `Server.swift`, replace the `allTools` computed property:

```swift
private static var allTools: [Tool] {
    [
        scheduleWorkoutToolDefinition,
        QueryWorkoutsTool.definition,
        QueryActivitySummaryTool.definition,
        QueryRestingHeartRateTool.definition,
        QueryVO2MaxTool.definition,
        QueryScheduledWorkoutsTool.definition,
        DeleteScheduledWorkoutTool.definition,
    ]
}
```

- [ ] **Step 2: Add dispatch cases to `handleToolCall`**

In `handleToolCall(_:)`, add two cases inside the `switch params.name` block, after the `QueryVO2MaxTool.toolName` case and before `default`:

```swift
case QueryScheduledWorkoutsTool.toolName:
    text = try await QueryScheduledWorkoutsTool.handle(manager: WorkoutKitManager())
case DeleteScheduledWorkoutTool.toolName:
    text = try await DeleteScheduledWorkoutTool.handle(args: args, manager: WorkoutKitManager())
```

> **Note:** The existing tools that use `WorkoutKitManager` (like `schedule_workout`) already instantiate `WorkoutKitManager()` inline. The `WorkoutKitManager` is an actor with no stored state beyond what it reads from WorkoutKit, so creating a new instance per call is consistent with the existing pattern.

- [ ] **Step 3: Build to verify no compile errors**

Build the `HealthKitMCP` target. Expected: build succeeds.

- [ ] **Step 4: Run all tests**

Run the full test suite. Expected: all existing tests still pass, plus the new tests from Tasks 1, 5, and 6.

- [ ] **Step 5: Commit**

```bash
git add HealthKitMCP/MCP/Server.swift
git commit -m "feat: wire query_scheduled_workouts and delete_scheduled_workout into MCP server"
```

---

## Manual Verification (on device)

After building and deploying to device:

1. Schedule a workout using `schedule_workout`
2. Call `query_scheduled_workouts` — verify the result includes the scheduled workout with an `index` of `0`
3. Call `delete_scheduled_workout` with `{"index": 0}` — verify it returns confirmation
4. Call `query_scheduled_workouts` again — verify the list is now empty
5. Call `delete_scheduled_workout` with `{"index": 0}` on an empty list — verify it returns an error message containing "found 0"
