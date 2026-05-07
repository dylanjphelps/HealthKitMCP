import Foundation

// MARK: - JSON encoding helpers

func encodeToCompactJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
}

func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
    try encodeToCompactJSON(value)
}

// MARK: - Shared response envelopes

struct PaginatedResults<T: Encodable & Sendable>: Encodable, Sendable {
    let count: Int
    let limit: Int
    let results: [T]
}

// MARK: - HealthKit result types

struct WorkoutResult: Codable, Sendable {
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

struct WorkoutSummaryResult: Codable, Sendable {
    let date: String
    let type: String
    let duration_minutes: Double
    let distance_miles: Double
    let active_calories: Double
}

struct SplitResult: Codable, Sendable {
    let mile: Int
    let pace_sec_per_mile: Double
    let elapsed_seconds: Double
}

struct IntervalResult: Codable, Sendable {
    let index: Int
    let type: String
    let duration_seconds: Double
    let distance_miles: Double?
    let pace_sec_per_mile: Double?
    let avg_heart_rate_bpm: Double?
}

struct ActivitySummaryResult: Codable, Sendable {
    let date: String
    let steps: Int
    let active_calories: Double
    let exercise_minutes: Double
}

struct RestingHRResult: Codable, Sendable {
    let date: String
    let avg_bpm: Double
    let min_bpm: Double?
    let max_bpm: Double?
}

struct VO2MaxResult: Codable, Sendable {
    let date: String
    let vo2max_ml_kg_min: Double
}

struct ScheduledWorkoutStepResult: Codable, Sendable {
    let purpose: String
    let goal_type: String
    let goal_value: Double?
    let target_pace_sec_per_mile: Double?
    let target_heart_rate_bpm: Double?
    let display_name: String?
}

struct ScheduledWorkoutBlockResult: Codable, Sendable {
    let iterations: Int
    let steps: [ScheduledWorkoutStepResult]
}

struct ScheduledWorkoutResult: Codable, Sendable {
    let index: Int
    let date: String
    let title: String
    let type: String
    let warmup: ScheduledWorkoutStepResult?
    let blocks: [ScheduledWorkoutBlockResult]?
    let cooldown: ScheduledWorkoutStepResult?

    init(index: Int, date: String, title: String, type: String,
         warmup: ScheduledWorkoutStepResult? = nil,
         blocks: [ScheduledWorkoutBlockResult]? = nil,
         cooldown: ScheduledWorkoutStepResult? = nil) {
        self.index = index
        self.date = date
        self.title = title
        self.type = type
        self.warmup = warmup
        self.blocks = blocks
        self.cooldown = cooldown
    }
}

struct ScheduledWorkoutSummaryResult: Codable, Sendable {
    let index: Int
    let date: String
    let title: String
    let type: String
}

struct HRVResult: Codable, Sendable {
    let date: String
    let avg_ms: Double
    let min_ms: Double?
    let max_ms: Double?
}

struct SleepStagesResult: Codable, Sendable {
    let awake_minutes: Double?
    let rem_minutes: Double?
    let core_minutes: Double?
    let deep_minutes: Double?
}

struct SleepResult: Codable, Sendable {
    let date: String
    let total_sleep_minutes: Double
    let time_in_bed_minutes: Double
    let stages: SleepStagesResult
}

struct BodyMassResult: Codable, Sendable {
    let date: String
    let weight_lbs: Double
}

// MARK: - Rounding helpers

extension WorkoutResult {
    var rounded: WorkoutResult {
        WorkoutResult(
            date: date,
            duration_minutes: roundedValue(duration_minutes),
            distance_miles: roundedValue(distance_miles),
            pace_sec_per_mile: roundedValue(pace_sec_per_mile),
            avg_heart_rate_bpm: avg_heart_rate_bpm.map { roundedValue($0) },
            max_heart_rate_bpm: max_heart_rate_bpm.map { roundedValue($0) },
            active_calories: roundedValue(active_calories),
            elevation_ascended_feet: elevation_ascended_feet.map { roundedValue($0) },
            elevation_descended_feet: elevation_descended_feet.map { roundedValue($0) },
            is_indoor: is_indoor,
            avg_running_power_watts: avg_running_power_watts.map { roundedValue($0) },
            max_running_power_watts: max_running_power_watts.map { roundedValue($0) },
            avg_cadence_spm: avg_cadence_spm.map { roundedValue($0) },
            avg_stride_length_feet: avg_stride_length_feet.map { roundedValue($0) },
            avg_vertical_oscillation_inches: avg_vertical_oscillation_inches.map { roundedValue($0) },
            avg_ground_contact_time_ms: avg_ground_contact_time_ms.map { roundedValue($0) },
            weather_temperature_fahrenheit: weather_temperature_fahrenheit.map { roundedValue($0) },
            weather_humidity_percent: weather_humidity_percent.map { roundedValue($0) },
            splits: splits?.map(\.rounded),
            intervals: intervals?.map(\.rounded)
        )
    }

    var summary: WorkoutSummaryResult {
        WorkoutSummaryResult(
            date: date,
            type: "running",
            duration_minutes: roundedValue(duration_minutes),
            distance_miles: roundedValue(distance_miles),
            active_calories: roundedValue(active_calories)
        )
    }
}

extension SplitResult {
    var rounded: SplitResult {
        SplitResult(
            mile: mile,
            pace_sec_per_mile: roundedValue(pace_sec_per_mile),
            elapsed_seconds: roundedValue(elapsed_seconds)
        )
    }
}

extension IntervalResult {
    var rounded: IntervalResult {
        IntervalResult(
            index: index,
            type: type,
            duration_seconds: roundedValue(duration_seconds),
            distance_miles: distance_miles.map { roundedValue($0) },
            pace_sec_per_mile: pace_sec_per_mile.map { roundedValue($0) },
            avg_heart_rate_bpm: avg_heart_rate_bpm.map { roundedValue($0) }
        )
    }
}

extension ActivitySummaryResult {
    var rounded: ActivitySummaryResult {
        ActivitySummaryResult(
            date: date,
            steps: steps,
            active_calories: roundedValue(active_calories),
            exercise_minutes: roundedValue(exercise_minutes)
        )
    }
}

extension RestingHRResult {
    var rounded: RestingHRResult {
        RestingHRResult(
            date: date,
            avg_bpm: roundedValue(avg_bpm),
            min_bpm: min_bpm.map { roundedValue($0) },
            max_bpm: max_bpm.map { roundedValue($0) }
        )
    }
}

extension VO2MaxResult {
    var rounded: VO2MaxResult {
        VO2MaxResult(
            date: date,
            vo2max_ml_kg_min: roundedValue(vo2max_ml_kg_min)
        )
    }
}

extension ScheduledWorkoutStepResult {
    var rounded: ScheduledWorkoutStepResult {
        ScheduledWorkoutStepResult(
            purpose: purpose,
            goal_type: goal_type,
            goal_value: goal_value.map { roundedValue($0) },
            target_pace_sec_per_mile: target_pace_sec_per_mile.map { roundedValue($0) },
            target_heart_rate_bpm: target_heart_rate_bpm.map { roundedValue($0) },
            display_name: display_name
        )
    }
}

extension ScheduledWorkoutBlockResult {
    var rounded: ScheduledWorkoutBlockResult {
        ScheduledWorkoutBlockResult(
            iterations: iterations,
            steps: steps.map(\.rounded)
        )
    }
}

extension ScheduledWorkoutResult {
    var rounded: ScheduledWorkoutResult {
        ScheduledWorkoutResult(
            index: index,
            date: date,
            title: title,
            type: type,
            warmup: warmup?.rounded,
            blocks: blocks?.map(\.rounded),
            cooldown: cooldown?.rounded
        )
    }

    var summary: ScheduledWorkoutSummaryResult {
        ScheduledWorkoutSummaryResult(index: index, date: date, title: title, type: type)
    }

    func detailed(includeSteps: Bool, includeIntervals: Bool) -> ScheduledWorkoutResult {
        ScheduledWorkoutResult(
            index: index,
            date: date,
            title: title,
            type: type,
            warmup: includeSteps ? warmup?.rounded : nil,
            blocks: includeIntervals ? blocks?.map(\.rounded) : nil,
            cooldown: includeSteps ? cooldown?.rounded : nil
        )
    }
}

extension HRVResult {
    var rounded: HRVResult {
        HRVResult(
            date: date,
            avg_ms: roundedValue(avg_ms),
            min_ms: min_ms.map { roundedValue($0) },
            max_ms: max_ms.map { roundedValue($0) }
        )
    }
}

extension SleepStagesResult {
    var rounded: SleepStagesResult {
        SleepStagesResult(
            awake_minutes: awake_minutes.map { roundedValue($0) },
            rem_minutes: rem_minutes.map { roundedValue($0) },
            core_minutes: core_minutes.map { roundedValue($0) },
            deep_minutes: deep_minutes.map { roundedValue($0) }
        )
    }
}

extension SleepResult {
    var rounded: SleepResult {
        SleepResult(
            date: date,
            total_sleep_minutes: roundedValue(total_sleep_minutes),
            time_in_bed_minutes: roundedValue(time_in_bed_minutes),
            stages: stages.rounded
        )
    }
}

extension BodyMassResult {
    var rounded: BodyMassResult {
        BodyMassResult(date: date, weight_lbs: roundedValue(weight_lbs))
    }
}
