// HealthKitMCP/MCP/Tools/ScheduleWorkoutTool.swift
import Foundation
import MCP

enum ScheduleWorkoutTool {
    static func handle(args: [String: Value]) async throws -> String {
        let title = args["title"]?.stringValue ?? ""
        guard !title.isEmpty else { return "Missing required parameter: title" }

        guard let blocksValue = args["blocks"], case .array(let blockArray) = blocksValue, !blockArray.isEmpty else {
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
        let (_, description) = try await manager.buildCustom(
            title: title,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )

        let shortcutsURL = buildShortcutsURL(
            title: title,
            date: scheduledDate,
            description: description,
            args: args
        )

        struct Result: Encodable {
            let title: String
            let date: String
            let description: String
            let shortcuts_url: String
            let instructions: String
        }

        return try encodeToJSON(Result(
            title: title,
            date: scheduledDate,
            description: description,
            shortcuts_url: shortcutsURL,
            instructions: "Open shortcuts_url on your iPhone to schedule this workout. Requires a Shortcut named 'Schedule Workout' — see setup instructions."
        ))
    }

    // MARK: - Shortcuts URL

    private static func buildShortcutsURL(
        title: String,
        date: String,
        description: String,
        args: [String: Value]
    ) -> String {
        // Encode a JSON payload the Shortcut can read via "Get Dictionary from Input"
        let payload: [String: Any] = [
            "title": title,
            "date": date,
            "description": description
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let encoded = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "shortcuts://run-shortcut?name=Schedule%20Workout"
        }
        return "shortcuts://run-shortcut?name=Schedule%20Workout&input=\(encoded)"
    }

    // MARK: - Parsing

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
}
