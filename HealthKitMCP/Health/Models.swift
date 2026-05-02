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
