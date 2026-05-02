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
    let distance_km: Double
    let pace_sec_per_km: Double
    let avg_heart_rate_bpm: Double?
    let active_calories: Double
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
