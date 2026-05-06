import XCTest
import WorkoutKit
import HealthKit
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

    func testSplitResultNilWhenNoSegments() throws {
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
        XCTAssertFalse(json.contains("\"splits\""), "nil splits should be omitted from JSON")
    }

    func testIntervalResultNilFieldsRoundTrip() throws {
        let interval = IntervalResult(index: 0, type: "recovery", duration_seconds: 240.0,
                                      distance_miles: nil, pace_sec_per_mile: nil,
                                      avg_heart_rate_bpm: nil)
        let json = try encodeToJSON(interval)
        let decoded = try JSONDecoder().decode(IntervalResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.type, "recovery")
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

    // MARK: - Scheduled workout step models

    func testScheduledWorkoutStepResultTimeGoalWithPaceRoundTrip() throws {
        let step = ScheduledWorkoutStepResult(
            purpose: "work",
            goal_type: "time",
            goal_value: 3.0,
            target_pace_sec_per_mile: 270.0,
            target_heart_rate_bpm: nil,
            display_name: nil
        )
        let json = try encodeToJSON(step)
        let decoded = try JSONDecoder().decode(ScheduledWorkoutStepResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.purpose, "work")
        XCTAssertEqual(decoded.goal_type, "time")
        XCTAssertEqual(decoded.goal_value, 3.0)
        XCTAssertEqual(decoded.target_pace_sec_per_mile, 270.0)
        XCTAssertNil(decoded.target_heart_rate_bpm)
        XCTAssertNil(decoded.display_name)
    }

    func testScheduledWorkoutBlockResultRoundTrip() throws {
        let work = ScheduledWorkoutStepResult(purpose: "work", goal_type: "time", goal_value: 3.0, target_pace_sec_per_mile: 270.0, target_heart_rate_bpm: nil, display_name: nil)
        let rest = ScheduledWorkoutStepResult(purpose: "recovery", goal_type: "time", goal_value: 1.5, target_pace_sec_per_mile: nil, target_heart_rate_bpm: nil, display_name: nil)
        let block = ScheduledWorkoutBlockResult(iterations: 6, steps: [work, rest])
        let json = try encodeToJSON(block)
        let decoded = try JSONDecoder().decode(ScheduledWorkoutBlockResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.iterations, 6)
        XCTAssertEqual(decoded.steps.count, 2)
        XCTAssertEqual(decoded.steps[0].purpose, "work")
        XCTAssertEqual(decoded.steps[1].purpose, "recovery")
    }

    func testScheduledWorkoutResultWithStepsRoundTrip() throws {
        let warmupStep = ScheduledWorkoutStepResult(purpose: "warmup", goal_type: "time", goal_value: 10.0, target_pace_sec_per_mile: nil, target_heart_rate_bpm: nil, display_name: nil)
        let work = ScheduledWorkoutStepResult(purpose: "work", goal_type: "time", goal_value: 3.0, target_pace_sec_per_mile: 270.0, target_heart_rate_bpm: nil, display_name: nil)
        let rest = ScheduledWorkoutStepResult(purpose: "recovery", goal_type: "time", goal_value: 1.5, target_pace_sec_per_mile: nil, target_heart_rate_bpm: nil, display_name: nil)
        let block = ScheduledWorkoutBlockResult(iterations: 6, steps: [work, rest])
        let cooldownStep = ScheduledWorkoutStepResult(purpose: "cooldown", goal_type: "time", goal_value: 5.0, target_pace_sec_per_mile: nil, target_heart_rate_bpm: nil, display_name: nil)
        let original = ScheduledWorkoutResult(
            index: 0,
            date: "2026-05-10",
            title: "6x3min",
            type: "custom",
            warmup: warmupStep,
            blocks: [block],
            cooldown: cooldownStep
        )
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(ScheduledWorkoutResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.warmup?.goal_value, 10.0)
        XCTAssertEqual(decoded.blocks?.count, 1)
        XCTAssertEqual(decoded.blocks?.first?.iterations, 6)
        XCTAssertEqual(decoded.blocks?.first?.steps.count, 2)
        XCTAssertEqual(decoded.cooldown?.goal_type, "time")
    }

    func testScheduledWorkoutResultNilStepsOmittedFromJSON() throws {
        let original = ScheduledWorkoutResult(index: 0, date: "2026-05-03", title: "Easy Run", type: "custom")
        let json = try encodeToJSON(original)
        XCTAssertFalse(json.contains("\"warmup\""), "nil warmup should be omitted")
        XCTAssertFalse(json.contains("\"blocks\""), "nil blocks should be omitted")
        XCTAssertFalse(json.contains("\"cooldown\""), "nil cooldown should be omitted")
    }

    func testStepResultFromTimeGoalWithPaceAlert() async throws {
        let manager = WorkoutKitManager()
        let speedAlert = SpeedRangeAlert(
            target: Measurement(value: 1609.344 / 280.0, unit: .metersPerSecond)
                ... Measurement(value: 1609.344 / 260.0, unit: .metersPerSecond),
            metric: .current
        )
        let step = WorkoutStep(goal: .time(3 * 60, .seconds), alert: speedAlert, displayName: "Fast interval")
        let result = await manager.stepResult(from: step, purpose: "work")
        XCTAssertEqual(result.purpose, "work")
        XCTAssertEqual(result.goal_type, "time")
        XCTAssertEqual(result.goal_value ?? 0, 3.0, accuracy: 0.01)
        XCTAssertEqual(result.target_pace_sec_per_mile ?? 0, 270.0, accuracy: 5.0)
        XCTAssertNil(result.target_heart_rate_bpm)
        XCTAssertEqual(result.display_name, "Fast interval")
    }

    func testStepResultFromDistanceGoalWithHRAlert() async throws {
        let manager = WorkoutKitManager()
        let hrAlert = HeartRateRangeAlert.heartRate(145.0...155.0)
        let step = WorkoutStep(goal: .distance(1.0, .miles), alert: hrAlert, displayName: nil)
        let result = await manager.stepResult(from: step, purpose: "work")
        XCTAssertEqual(result.goal_type, "distance")
        XCTAssertEqual(result.goal_value ?? 0, 1.0, accuracy: 0.001)
        XCTAssertNil(result.target_pace_sec_per_mile)
        XCTAssertEqual(result.target_heart_rate_bpm ?? 0, 150.0, accuracy: 0.1)
        XCTAssertNil(result.display_name)
    }

    func testStepResultFromOpenGoal() async throws {
        let manager = WorkoutKitManager()
        let step = WorkoutStep(goal: .open, alert: nil, displayName: nil)
        let result = await manager.stepResult(from: step, purpose: "warmup")
        XCTAssertEqual(result.goal_type, "open")
        XCTAssertNil(result.goal_value)
        XCTAssertNil(result.target_pace_sec_per_mile)
        XCTAssertNil(result.target_heart_rate_bpm)
    }

    // MARK: - Interval type label

    func testActivityTypeLabelMapsAllSpecifiedCases() {
        XCTAssertEqual(activityTypeLabel(.cooldown), "cooldown")
        XCTAssertEqual(activityTypeLabel(.preparationAndRecovery), "recovery")
        XCTAssertEqual(activityTypeLabel(.running), "run")
        XCTAssertEqual(activityTypeLabel(.walking), "walk")
        XCTAssertEqual(activityTypeLabel(.cycling), "segment")
    }

    // MARK: - HRV models

    func testHRVResultRoundTrip() throws {
        let original = HRVResult(date: "2026-05-01", avg_ms: 45.2, min_ms: 38.0, max_ms: 52.0)
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(HRVResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.date, "2026-05-01")
        XCTAssertEqual(decoded.avg_ms, 45.2)
        XCTAssertEqual(decoded.min_ms, 38.0)
        XCTAssertEqual(decoded.max_ms, 52.0)
    }

    func testHRVResultNilFieldsOmittedFromJSON() throws {
        let original = HRVResult(date: "2026-05-01", avg_ms: 45.2, min_ms: nil, max_ms: nil)
        let json = try encodeToJSON(original)
        XCTAssertFalse(json.contains("\"min_ms\""))
        XCTAssertFalse(json.contains("\"max_ms\""))
    }

    // MARK: - Sleep models

    func testSleepResultRoundTrip() throws {
        let stages = SleepStagesResult(awake_minutes: 12.0, rem_minutes: 90.0, core_minutes: 150.0, deep_minutes: 60.0)
        let original = SleepResult(date: "2026-05-01", total_sleep_minutes: 300.0, time_in_bed_minutes: 420.0, stages: stages)
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(SleepResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.date, "2026-05-01")
        XCTAssertEqual(decoded.total_sleep_minutes, 300.0)
        XCTAssertEqual(decoded.time_in_bed_minutes, 420.0)
        XCTAssertEqual(decoded.stages.rem_minutes, 90.0)
        XCTAssertEqual(decoded.stages.core_minutes, 150.0)
        XCTAssertEqual(decoded.stages.deep_minutes, 60.0)
        XCTAssertEqual(decoded.stages.awake_minutes, 12.0)
    }

    func testSleepStagesNilFieldsOmittedFromJSON() throws {
        let stages = SleepStagesResult(awake_minutes: nil, rem_minutes: nil, core_minutes: nil, deep_minutes: nil)
        let original = SleepResult(date: "2026-05-01", total_sleep_minutes: 420.0, time_in_bed_minutes: 480.0, stages: stages)
        let json = try encodeToJSON(original)
        XCTAssertFalse(json.contains("\"awake_minutes\""))
        XCTAssertFalse(json.contains("\"rem_minutes\""))
        XCTAssertFalse(json.contains("\"core_minutes\""))
        XCTAssertFalse(json.contains("\"deep_minutes\""))
    }

    // MARK: - Body mass models

    func testBodyMassResultRoundTrip() throws {
        let original = BodyMassResult(date: "2026-05-01", weight_lbs: 165.3)
        let json = try encodeToJSON(original)
        let decoded = try JSONDecoder().decode(BodyMassResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.date, "2026-05-01")
        XCTAssertEqual(decoded.weight_lbs, 165.3)
    }
}

// MARK: - Sleep aggregation

final class SleepAggregationTests: XCTestCase {

    private var utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return utcCalendar.date(from: comps)!
    }

    private func makeSample(_ kind: HKCategoryValueSleepAnalysis, _ start: Date, _ end: Date) -> HKCategorySample {
        HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: kind.rawValue, start: start, end: end)
    }

    func testEmptySamplesReturnsEmptyArray() {
        XCTAssertTrue(sleepResults(from: [], calendar: utcCalendar).isEmpty)
    }

    func testInBedSampleGroupedToStartDate() {
        let s = makeSample(.inBed, makeDate(2026, 5, 4, 22), makeDate(2026, 5, 5, 6))
        let results = sleepResults(from: [s], calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].date, "2026-05-04")
        XCTAssertEqual(results[0].time_in_bed_minutes, 480.0, accuracy: 0.01)
        XCTAssertEqual(results[0].total_sleep_minutes, 0.0, accuracy: 0.01)
    }

    func testStageDurationsAccumulatedCorrectly() throws {
        // Night of May 4: 10pm–6am
        let samples: [HKCategorySample] = [
            makeSample(.inBed,      makeDate(2026, 5, 4, 22, 0),  makeDate(2026, 5, 5, 6, 0)),
            makeSample(.asleepCore, makeDate(2026, 5, 4, 22, 15), makeDate(2026, 5, 5, 0, 15)), // 120 min
            makeSample(.asleepREM,  makeDate(2026, 5, 5, 0, 15),  makeDate(2026, 5, 5, 1, 15)), // 60 min
            makeSample(.asleepDeep, makeDate(2026, 5, 5, 1, 15),  makeDate(2026, 5, 5, 2, 15)), // 60 min
            makeSample(.awake,      makeDate(2026, 5, 5, 2, 15),  makeDate(2026, 5, 5, 2, 30)), // 15 min
        ]
        let results = sleepResults(from: samples, calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        let r = results[0]
        XCTAssertEqual(r.date, "2026-05-04")
        XCTAssertEqual(r.total_sleep_minutes, 240.0, accuracy: 0.01)
        XCTAssertEqual(r.time_in_bed_minutes, 480.0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(r.stages.core_minutes),  120.0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(r.stages.rem_minutes),    60.0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(r.stages.deep_minutes),   60.0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(r.stages.awake_minutes),  15.0, accuracy: 0.01)
    }

    func testStageFieldsNilWhenStageAbsent() {
        // Only inBed — no stage breakdown recorded
        let s = makeSample(.inBed, makeDate(2026, 5, 4, 22), makeDate(2026, 5, 5, 6))
        let results = sleepResults(from: [s], calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results[0].stages.rem_minutes)
        XCTAssertNil(results[0].stages.core_minutes)
        XCTAssertNil(results[0].stages.deep_minutes)
        XCTAssertNil(results[0].stages.awake_minutes)
    }

    func testTwoNightsReturnedChronologically() {
        let samples: [HKCategorySample] = [
            makeSample(.inBed, makeDate(2026, 5, 5, 22), makeDate(2026, 5, 6, 6)),
            makeSample(.inBed, makeDate(2026, 5, 4, 22), makeDate(2026, 5, 5, 6)),
        ]
        let results = sleepResults(from: samples, calendar: utcCalendar)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].date, "2026-05-04")
        XCTAssertEqual(results[1].date, "2026-05-05")
    }

    func testSessionStartingJustBeforeMidnightGroupedToStartDate() {
        // Starts 11:59pm May 4, wakes 6am May 5 — should be "2026-05-04"
        let s = makeSample(.inBed, makeDate(2026, 5, 4, 23, 59), makeDate(2026, 5, 5, 6, 0))
        let results = sleepResults(from: [s], calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].date, "2026-05-04")
    }

    func testAsleepUnspecifiedCountsTowardTotalSleepButNoStageBreakdown() {
        let samples: [HKCategorySample] = [
            makeSample(.inBed,            makeDate(2026, 5, 4, 22), makeDate(2026, 5, 5, 6)), // 480 min
            makeSample(.asleepUnspecified, makeDate(2026, 5, 4, 22, 30), makeDate(2026, 5, 5, 5, 30)), // 420 min
        ]
        let results = sleepResults(from: samples, calendar: utcCalendar)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].total_sleep_minutes, 420.0, accuracy: 0.01)
        XCTAssertNil(results[0].stages.core_minutes)
        XCTAssertNil(results[0].stages.rem_minutes)
        XCTAssertNil(results[0].stages.deep_minutes)
    }
}
