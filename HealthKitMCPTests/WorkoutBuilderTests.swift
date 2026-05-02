import XCTest
import WorkoutKit
@testable import HealthKitMCP

final class WorkoutBuilderTests: XCTestCase {

    // MARK: - Model encoding

    func testWorkoutResultEncodesCorrectly() throws {
        let result = WorkoutResult(
            date: "2026-04-28T06:00:00Z",
            duration_minutes: 45.0,
            distance_km: 8.5,
            pace_sec_per_km: 318.0,
            avg_heart_rate_bpm: 152.0,
            active_calories: 520.0
        )
        let json = try encodeToJSON(result)
        XCTAssertTrue(json.contains("\"distance_km\":8.5"))
        XCTAssertTrue(json.contains("\"avg_heart_rate_bpm\":152"))
    }

    func testWorkoutResultNilHeartRateOmittedFromJSON() throws {
        let result = WorkoutResult(
            date: "2026-04-28T06:00:00Z",
            duration_minutes: 30.0,
            distance_km: 5.0,
            pace_sec_per_km: 360.0,
            avg_heart_rate_bpm: nil,
            active_calories: 300.0
        )
        let json = try encodeToJSON(result)
        // Swift's JSONEncoder omits nil optionals by default — key is absent rather than null
        XCTAssertFalse(json.contains("avg_heart_rate_bpm"))
    }

    func testActivitySummaryEncodesSteps() throws {
        let result = ActivitySummaryResult(date: "2026-04-28", steps: 9823, active_calories: 480.0, exercise_minutes: 42.0)
        let json = try encodeToJSON(result)
        XCTAssertTrue(json.contains("\"steps\":9823"))
        XCTAssertTrue(json.contains("\"exercise_minutes\":42"))
    }

    func testVO2MaxEncodes() throws {
        let result = VO2MaxResult(date: "2026-04-20", vo2max_ml_kg_min: 52.3)
        let json = try encodeToJSON(result)
        XCTAssertTrue(json.contains("\"vo2max_ml_kg_min\":52.3"))
    }

    // MARK: - WorkoutKitManager description
    // describeWorkout builds parts joined by " → ".
    // stepLabel returns "<value>km" for distance goals and "<value>min" for time goals.
    // A single-rep block with no rest appends just the step label.
    // A multi-rep block with rest appends "<n>×(<work> + <rest> recovery)".

    func testSimpleEasyRunDescription() async throws {
        let manager = WorkoutKitManager()
        let work = StepSpec(goalType: "distance", goalValue: 5, targetPaceSecPerKm: nil, targetHeartRateBpm: 140)
        let block = BlockSpec(repeatCount: 1, work: work, rest: nil)
        let desc = await manager.describeWorkout(title: "Easy 5k", warmup: nil, blocks: [block], cooldown: nil)
        // Single block, distance=5km, no rest, repeatCount=1 → "5.0km"
        XCTAssertEqual(desc, "5.0km")
    }

    func testIntervalBlockDescription() async throws {
        let manager = WorkoutKitManager()
        let work = StepSpec(goalType: "time", goalValue: 3, targetPaceSecPerKm: 270, targetHeartRateBpm: nil)
        let rest = StepSpec(goalType: "time", goalValue: 1.5, targetPaceSecPerKm: nil, targetHeartRateBpm: nil)
        let block = BlockSpec(repeatCount: 6, work: work, rest: rest)
        let desc = await manager.describeWorkout(title: "6x3min", warmup: nil, blocks: [block], cooldown: nil)
        // repeatCount=6 with rest → "6×(3.0min + 1.5min recovery)"
        XCTAssertEqual(desc, "6×(3.0min + 1.5min recovery)")
    }
}
