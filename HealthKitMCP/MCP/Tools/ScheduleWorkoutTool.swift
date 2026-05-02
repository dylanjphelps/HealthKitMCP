// HealthKitMCP/MCP/Tools/ScheduleWorkoutTool.swift
import Foundation
import MCP

enum ScheduleWorkoutTool {
    static func handle(args: [String: Value]) async throws -> String {
        let title = args["title"]?.stringValue ?? ""
        guard !title.isEmpty else { return "Missing required parameter: title" }

        guard let blocksValue = args["blocks"],
              case .array(let blockArray) = blocksValue, !blockArray.isEmpty else {
            return "Missing required parameter: blocks (must be a non-empty array)"
        }

        let scheduledDate = args["scheduled_date"]?.stringValue ?? isoToday()
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

        let date = parseDate(from: scheduledDate)
        try await manager.schedule(workout, for: date)

        struct Result: Encodable {
            let title: String
            let date: String
            let description: String
            let scheduled: Bool
        }

        return try encodeToJSON(Result(
            title: title,
            date: scheduledDate,
            description: description,
            scheduled: true
        ))
    }

    // MARK: - Parsing

    private static func parseStepSpec(from value: Value?) -> StepSpec? {
        guard let value, case .object(let obj) = value else { return nil }
        let goalType = obj["goal_type"]?.stringValue ?? "time"
        let goalValue = obj["goal_value"]?.doubleValue ?? obj["goal_value"]?.intValue.map(Double.init) ?? 0
        let pace = obj["target_pace_seconds_per_mile"]?.doubleValue ?? obj["target_pace_seconds_per_mile"]?.intValue.map(Double.init)
        let hr = obj["target_heart_rate_bpm"]?.doubleValue ?? obj["target_heart_rate_bpm"]?.intValue.map(Double.init)
        return StepSpec(goalType: goalType, goalValue: goalValue, targetPaceSecPerMile: pace, targetHeartRateBpm: hr)
    }

    private static func parseBlockSpec(from value: Value) -> BlockSpec? {
        guard case .object(let obj) = value else { return nil }
        let repeatCount: Int
        if let v = obj["repeat_count"]?.intValue { repeatCount = v }
        else if let v = obj["repeat_count"]?.doubleValue { repeatCount = Int(v) }
        else { repeatCount = 1 }
        guard let work = parseStepSpec(from: obj["work"]) else { return nil }
        return BlockSpec(repeatCount: repeatCount, work: work, rest: parseStepSpec(from: obj["rest"]))
    }

    private static func isoToday() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }

    private static func parseDate(from iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso) ?? Date()
    }
}
