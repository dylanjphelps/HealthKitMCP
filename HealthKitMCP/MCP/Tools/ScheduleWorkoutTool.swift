// HealthKitMCP/MCP/Tools/ScheduleWorkoutTool.swift
import Foundation
import MCP
import WorkoutKit

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
        let displayName = obj["display_name"]?.stringValue
        return StepSpec(goalType: goalType, goalValue: goalValue, targetPaceSecPerMile: pace, targetHeartRateBpm: hr, displayName: displayName)
    }

    static func parseBlockSpec(from value: Value) -> BlockSpec? {
        guard case .object(let obj) = value else { return nil }
        if obj["steps"] == nil {
            guard let spec = parseStepSpec(from: value) else { return nil }
            let purpose: IntervalStep.Purpose = obj["purpose"]?.stringValue == "recovery" ? .recovery : .work
            return BlockSpec(repeatCount: 1, steps: [(purpose, spec)])
        }
        guard case .array(let stepsArray) = obj["steps"] else { return nil }
        let repeatCount: Int
        if let v = obj["repeat_count"]?.intValue { repeatCount = v }
        else if let v = obj["repeat_count"]?.doubleValue { repeatCount = Int(v) }
        else { repeatCount = 1 }
        let steps: [(IntervalStep.Purpose, StepSpec)] = stepsArray.compactMap { stepValue in
            guard case .object(let stepObj) = stepValue,
                  let spec = parseStepSpec(from: stepValue) else { return nil }
            let purpose: IntervalStep.Purpose = stepObj["purpose"]?.stringValue == "recovery" ? .recovery : .work
            return (purpose, spec)
        }
        guard !steps.isEmpty else { return nil }
        return BlockSpec(repeatCount: repeatCount, steps: steps)
    }

    private static func isoToday() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }

    private static func parseDate(from iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return f.date(from: iso) ?? Date()
    }
}
