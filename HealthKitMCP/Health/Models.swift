import Foundation

// MARK: - JSON encoding helper

func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
}

// MARK: - HealthKit result types

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

struct ActivitySummaryResult: Codable {
    let date: String
    let steps: Int
    let active_calories: Double
    let exercise_minutes: Double
}

struct RestingHRResult: Codable {
    let date: String
    let avg_bpm: Double
    let min_bpm: Double?
    let max_bpm: Double?
}

struct VO2MaxResult: Codable {
    let date: String
    let vo2max_ml_kg_min: Double
}

struct ScheduledWorkoutStepResult: Codable {
    let purpose: String
    let goal_type: String
    let goal_value: Double?
    let target_pace_sec_per_mile: Double?
    let target_heart_rate_bpm: Double?
    let display_name: String?
}

struct ScheduledWorkoutBlockResult: Codable {
    let iterations: Int
    let steps: [ScheduledWorkoutStepResult]
}

struct ScheduledWorkoutResult: Codable {
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

struct HRVResult: Codable {
    let date: String
    let avg_ms: Double
    let min_ms: Double?
    let max_ms: Double?
}

struct SleepStagesResult: Codable {
    let awake_minutes: Double?
    let rem_minutes: Double?
    let core_minutes: Double?
    let deep_minutes: Double?
}

struct SleepResult: Codable {
    let date: String
    let total_sleep_minutes: Double
    let time_in_bed_minutes: Double
    let stages: SleepStagesResult
}

struct BodyMassResult: Codable {
    let date: String
    let weight_lbs: Double
}
