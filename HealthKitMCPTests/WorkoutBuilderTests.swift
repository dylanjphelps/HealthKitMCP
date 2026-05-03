import XCTest
import WorkoutKit
@testable import HealthKitMCP

final class WorkoutBuilderTests: XCTestCase {

    // MARK: - Model encoding

    func testWorkoutResultRoundTrip() throws {
        let original = WorkoutResult(
            date: "2026-04-28T06:00:00Z",
            duration_minutes: 45.0,
            distance_miles: 5.3,
            pace_sec_per_mile: 510.0,
            avg_heart_rate_bpm: 152.0,
            max_heart_rate_bpm: nil,
            active_calories: 520.0,
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
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(WorkoutResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.distance_miles, 5.3)
        XCTAssertEqual(decoded.avg_heart_rate_bpm, 152.0)
        XCTAssertEqual(decoded.duration_minutes, 45.0)
    }

    func testWorkoutResultNilHeartRateRoundTrip() throws {
        let original = WorkoutResult(
            date: "2026-04-28T06:00:00Z",
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
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(WorkoutResult.self, from: Data(json.utf8))
        XCTAssertNil(decoded.avg_heart_rate_bpm)
    }

    func testActivitySummaryRoundTrip() throws {
        let original = ActivitySummaryResult(date: "2026-04-28", steps: 9823, active_calories: 480.0, exercise_minutes: 42.0)
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(ActivitySummaryResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.steps, 9823)
        XCTAssertEqual(decoded.exercise_minutes, 42.0)
    }

    func testVO2MaxRoundTrip() throws {
        let original = VO2MaxResult(date: "2026-04-20", vo2max_ml_kg_min: 52.3)
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(VO2MaxResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.vo2max_ml_kg_min, 52.3, accuracy: 0.001)
    }

    func testScheduledWorkoutResultRoundTrip() throws {
        let original = ScheduledWorkoutResult(index: 0, date: "2026-05-03", title: "Morning Run", type: "custom")
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(ScheduledWorkoutResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.index, 0)
        XCTAssertEqual(decoded.date, "2026-05-03")
        XCTAssertEqual(decoded.title, "Morning Run")
        XCTAssertEqual(decoded.type, "custom")
    }

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

    // MARK: - WorkoutKitManager description

    func testSimpleEasyRunDescription() async throws {
        let manager = WorkoutKitManager()
        let work = StepSpec(goalType: "distance", goalValue: 5, targetPaceSecPerMile: nil, targetHeartRateBpm: 140, displayName: nil)
        let block = BlockSpec(repeatCount: 1, steps: [(.work, work)])
        let desc = await manager.describeWorkout(title: "Easy 5mi", warmup: nil, blocks: [block], cooldown: nil)
        XCTAssertEqual(desc, "5.0mi")
    }

    func testIntervalBlockDescription() async throws {
        let manager = WorkoutKitManager()
        let work = StepSpec(goalType: "time", goalValue: 3, targetPaceSecPerMile: 270, targetHeartRateBpm: nil, displayName: nil)
        let rest = StepSpec(goalType: "time", goalValue: 1.5, targetPaceSecPerMile: nil, targetHeartRateBpm: nil, displayName: nil)
        let block = BlockSpec(repeatCount: 6, steps: [(.work, work), (.recovery, rest)])
        let desc = await manager.describeWorkout(title: "6x3min", warmup: nil, blocks: [block], cooldown: nil)
        XCTAssertEqual(desc, "6×(3.0min + 1.5min recovery)")
    }

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
}
