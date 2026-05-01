// HealthKitMCP/MCP/Tools/ScheduleWorkoutTool.swift
import Foundation
import MCP

@available(macOS 15.0, *)
enum ScheduleWorkoutTool {
    static func handle(args: [String: Value]) async throws -> String {
        let title = args["title"]?.stringValue ?? ""
        guard !title.isEmpty else { return "Missing required parameter: title" }

        guard let blocksValue = args["blocks"], case .array(let blockArray) = blocksValue, !blockArray.isEmpty else {
            return "Missing required parameter: blocks (must be a non-empty array)"
        }

        let dryRun = args["dry_run"]?.boolValue ?? false
        let scheduledDate = args["scheduled_date"]?.stringValue

        let warmup = parseStepSpec(from: args["warmup"])
        let cooldown = parseStepSpec(from: args["cooldown"])
        let blocks = blockArray.compactMap { parseBlockSpec(from: $0) }

        guard !blocks.isEmpty else {
            return "blocks array contained no valid block objects"
        }

        let manager = WorkoutKitManager()
        let (workout, description) = try await manager.buildCustom(
            title: title,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )

        if dryRun {
            return try encodeToJSON(DryRunResult(scheduled: false, valid: true, workout_description: description))
        }

        try await manager.schedule(workout, on: scheduledDate)
        return try encodeToJSON(ScheduleResult(scheduled: true, title: title, date: scheduledDate ?? "today"))
    }

    private static func parseStepSpec(from value: Value?) -> StepSpec? {
        guard let value, case .object(let obj) = value else { return nil }
        let goalType = obj["goal_type"]?.stringValue ?? "time"
        let goalValue = obj["goal_value"]?.doubleValue ?? obj["goal_value"]?.intValue.map(Double.init) ?? 0
        let pace = obj["target_pace_seconds_per_km"]?.doubleValue ?? obj["target_pace_seconds_per_km"]?.intValue.map(Double.init)
        let hr = obj["target_heart_rate_bpm"]?.doubleValue ?? obj["target_heart_rate_bpm"]?.intValue.map(Double.init)
        return StepSpec(goalType: goalType, goalValue: goalValue, targetPaceSecPerKm: pace, targetHeartRateBpm: hr)
    }

    private static func parseBlockSpec(from value: Value) -> BlockSpec? {
        guard case .object(let obj) = value else { return nil }
        let repeatCount: Int
        if let v = obj["repeat_count"]?.intValue {
            repeatCount = v
        } else if let v = obj["repeat_count"]?.doubleValue {
            repeatCount = Int(v)
        } else {
            repeatCount = 1
        }
        guard let work = parseStepSpec(from: obj["work"]) else { return nil }
        let rest = parseStepSpec(from: obj["rest"])
        return BlockSpec(repeatCount: repeatCount, work: work, rest: rest)
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
    let date: String
}
