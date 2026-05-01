// HealthKitMCP/Health/WorkoutKitManager.swift
import WorkoutKit
import Foundation

@available(macOS 15.0, *)
actor WorkoutKitManager {

    func buildAndDescribe(
        type: String,
        title: String,
        params: [String: Any]
    ) throws -> (workout: CustomWorkout, description: String) {
        switch type {
        case "easy":
            return try buildEasy(title: title, params: params)
        case "tempo":
            return try buildTempo(title: title, params: params)
        case "interval":
            return try buildInterval(title: title, params: params)
        default:
            throw WorkoutError.invalidType(type)
        }
    }

    /// Wraps the CustomWorkout in a WorkoutPlan and schedules it for today via WorkoutScheduler.
    func schedule(_ workout: CustomWorkout) async throws {
        let plan = WorkoutPlan(.custom(workout))
        let date = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        await WorkoutScheduler.shared.schedule(plan, at: date)
    }

    // MARK: - Builders

    private func buildEasy(title: String, params: [String: Any]) throws -> (CustomWorkout, String) {
        let goalType = params["goal_type"] as? String ?? "time"
        let goalValue = params["goal_value"] as? Double ?? 30

        let goal: WorkoutGoal
        switch goalType {
        case "distance": goal = .distance(goalValue * 1000, .meters)
        case "open": goal = .open
        default: goal = .time(goalValue * 60, .seconds)
        }

        // IntervalStep uses a positional first argument for purpose (no label)
        let step = IntervalStep(.work, goal: goal, alert: nil)
        let workout = CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: title,
            warmup: nil,
            blocks: [IntervalBlock(steps: [step], iterations: 1)],
            cooldown: nil
        )

        let description: String
        switch goalType {
        case "distance": description = "Easy run: \(goalValue) km"
        case "open": description = "Easy run: open goal"
        default: description = "Easy run: \(Int(goalValue)) minutes"
        }

        return (workout, description)
    }

    private func buildTempo(title: String, params: [String: Any]) throws -> (CustomWorkout, String) {
        let warmupMin = params["warmup_minutes"] as? Double ?? 5
        let tempoKm = params["tempo_distance_km"] as? Double ?? 3
        let paceSecPerKm = params["target_pace_seconds_per_km"] as? Double ?? 270
        let cooldownMin = params["cooldown_minutes"] as? Double ?? 5

        // WorkoutKit has no pace alert; use SpeedRangeAlert with m/s (speed = 1000 / pace_sec_per_km)
        let speedAlert = paceAlert(paceSecPerKm: paceSecPerKm, toleranceSec: 10)

        let warmup = WorkoutStep(goal: .time(warmupMin * 60, .seconds), alert: nil)
        let tempoStep = IntervalStep(
            .work,
            goal: .distance(tempoKm * 1000, .meters),
            alert: speedAlert
        )
        let cooldown = WorkoutStep(goal: .time(cooldownMin * 60, .seconds), alert: nil)

        let workout = CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: title,
            warmup: warmup,
            blocks: [IntervalBlock(steps: [tempoStep], iterations: 1)],
            cooldown: cooldown
        )

        let description = "Tempo run: \(Int(warmupMin))min warmup → \(tempoKm)km at \(formatPace(paceSecPerKm))/km → \(Int(cooldownMin))min cooldown"
        return (workout, description)
    }

    private func buildInterval(title: String, params: [String: Any]) throws -> (CustomWorkout, String) {
        let warmupMin = params["warmup_minutes"] as? Double ?? 5
        let repeatCount = params["repeat_count"] as? Int ?? 6
        let workMeters = params["work_distance_meters"] as? Double ?? 400
        let restMeters = params["rest_distance_meters"] as? Double ?? 200
        let paceSecPerKm = params["target_pace_seconds_per_km"] as? Double ?? 240
        let cooldownMin = params["cooldown_minutes"] as? Double ?? 5

        let speedAlert = paceAlert(paceSecPerKm: paceSecPerKm, toleranceSec: 10)

        let warmup = WorkoutStep(goal: .time(warmupMin * 60, .seconds), alert: nil)
        let workStep = IntervalStep(
            .work,
            goal: .distance(workMeters, .meters),
            alert: speedAlert
        )
        let restStep = IntervalStep(
            .recovery,
            goal: .distance(restMeters, .meters),
            alert: nil
        )
        let cooldown = WorkoutStep(goal: .time(cooldownMin * 60, .seconds), alert: nil)

        let workout = CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: title,
            warmup: warmup,
            blocks: [IntervalBlock(steps: [workStep, restStep], iterations: repeatCount)],
            cooldown: cooldown
        )

        let description = "Interval run: \(Int(warmupMin))min warmup → \(repeatCount)×(\(Int(workMeters))m at \(formatPace(paceSecPerKm))/km + \(Int(restMeters))m recovery) → \(Int(cooldownMin))min cooldown"
        return (workout, description)
    }

    // MARK: - Helpers

    /// Converts a target pace (seconds/km) ± tolerance into a SpeedRangeAlert (m/s).
    /// WorkoutKit does not expose a pace alert; speed = 1000 / paceSecPerKm.
    private func paceAlert(paceSecPerKm: Double, toleranceSec: Double) -> SpeedRangeAlert {
        // Faster pace (fewer seconds) → higher speed; clamp to avoid div/0
        let slowPace = paceSecPerKm + toleranceSec
        let fastPace = max(paceSecPerKm - toleranceSec, 1.0)
        let slowSpeedMps = 1000.0 / slowPace
        let fastSpeedMps = 1000.0 / fastPace
        return SpeedRangeAlert(
            target: Measurement(value: slowSpeedMps, unit: .metersPerSecond)
                ... Measurement(value: fastSpeedMps, unit: .metersPerSecond),
            metric: .current
        )
    }

    private func formatPace(_ secondsPerKm: Double) -> String {
        let min = Int(secondsPerKm) / 60
        let sec = Int(secondsPerKm) % 60
        return "\(min):\(String(format: "%02d", sec))"
    }
}

enum WorkoutError: Error, LocalizedError {
    case invalidType(String)

    var errorDescription: String? {
        switch self {
        case .invalidType(let t):
            return "Unknown workout_type '\(t)'. Must be easy, tempo, or interval."
        }
    }
}
