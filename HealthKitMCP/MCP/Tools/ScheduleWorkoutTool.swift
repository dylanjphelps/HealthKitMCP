// HealthKitMCP/MCP/Tools/ScheduleWorkoutTool.swift
import Foundation
import MCP

enum ScheduleWorkoutTool {
    static func handle(args: [String: Value]) async throws -> String {
        guard #available(macOS 15.0, *) else {
            return "WorkoutKit is not available on this macOS version. macOS 15.0 or later is required."
        }

        let workoutType = args["workout_type"]?.stringValue ?? ""
        let title = args["title"]?.stringValue ?? ""
        let dryRun = args["dry_run"]?.boolValue ?? false

        guard !workoutType.isEmpty else {
            return "Missing required parameter: workout_type"
        }
        guard !title.isEmpty else {
            return "Missing required parameter: title"
        }

        // Build a [String: Any] params dictionary from MCP Value args
        var params: [String: Any] = [:]

        if let v = args["goal_type"]?.stringValue { params["goal_type"] = v }
        if let v = args["goal_value"]?.doubleValue { params["goal_value"] = v }
        else if let v = args["goal_value"]?.intValue { params["goal_value"] = Double(v) }

        if let v = args["warmup_minutes"]?.doubleValue { params["warmup_minutes"] = v }
        else if let v = args["warmup_minutes"]?.intValue { params["warmup_minutes"] = Double(v) }

        if let v = args["tempo_distance_km"]?.doubleValue { params["tempo_distance_km"] = v }
        else if let v = args["tempo_distance_km"]?.intValue { params["tempo_distance_km"] = Double(v) }

        if let v = args["target_pace_seconds_per_km"]?.doubleValue { params["target_pace_seconds_per_km"] = v }
        else if let v = args["target_pace_seconds_per_km"]?.intValue { params["target_pace_seconds_per_km"] = Double(v) }

        if let v = args["cooldown_minutes"]?.doubleValue { params["cooldown_minutes"] = v }
        else if let v = args["cooldown_minutes"]?.intValue { params["cooldown_minutes"] = Double(v) }

        if let v = args["repeat_count"]?.intValue { params["repeat_count"] = v }
        else if let v = args["repeat_count"]?.doubleValue { params["repeat_count"] = Int(v) }

        if let v = args["work_distance_meters"]?.doubleValue { params["work_distance_meters"] = v }
        else if let v = args["work_distance_meters"]?.intValue { params["work_distance_meters"] = Double(v) }

        if let v = args["rest_distance_meters"]?.doubleValue { params["rest_distance_meters"] = v }
        else if let v = args["rest_distance_meters"]?.intValue { params["rest_distance_meters"] = Double(v) }

        let manager = WorkoutKitManager()
        let (workout, description) = try await manager.buildAndDescribe(
            type: workoutType,
            title: title,
            params: params
        )

        if dryRun {
            return try encodeToJSON(DryRunResult(
                scheduled: false,
                valid: true,
                workout_description: description
            ))
        }

        try await manager.schedule(workout)
        return try encodeToJSON(ScheduleResult(
            scheduled: true,
            title: title,
            type: workoutType
        ))
    }
}

// MARK: - Response types

private struct DryRunResult: Encodable {
    let scheduled: Bool
    let valid: Bool
    let workout_description: String
}

private struct ScheduleResult: Encodable {
    let scheduled: Bool
    let title: String
    let type: String
}
