// HealthKitMCP/Health/Models.swift
import Foundation

struct WorkoutRecord: Encodable {
    let date: String
    let duration_minutes: Double
    let distance_km: Double
    let avg_pace_sec_per_km: Double
    let avg_heart_rate_bpm: Double?
    let max_heart_rate_bpm: Double?
    let active_calories_kcal: Double
}

struct ActivitySummaryRecord: Encodable {
    let date: String
    let steps: Int
    let active_energy_kcal: Double
    let exercise_minutes: Int
}

struct HeartRateRecord: Encodable {
    let date: String
    let avg_resting_hr_bpm: Double
    let min_resting_hr_bpm: Double
    let max_resting_hr_bpm: Double
}

struct VO2MaxRecord: Encodable {
    let value_ml_per_kg_per_min: Double
    let date: String
    let source: String
}

// Shared date helpers
enum DateHelpers {
    static let isoDay: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    static func defaultRange() -> (start: Date, end: Date) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        return (start, end)
    }

    static func parse(_ string: String) -> Date? {
        isoDay.date(from: string)
    }
}

// Typed error for HealthKit query failures — allows use in Result<T, HKMCPError>
struct HKMCPError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// JSON encoding helper used by all tool handlers
func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
    let data = try JSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
}
