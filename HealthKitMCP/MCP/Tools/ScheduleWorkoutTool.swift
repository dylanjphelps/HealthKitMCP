import Foundation
import MCP
import WorkoutKit

enum ScheduleWorkoutTool {
    static let toolName = "schedule_workout"

    static let definition = Tool(
        name: toolName,
        description: "Schedules a structured running workout directly to Apple Watch via WorkoutKit. Supports warmup, a sequence of segments, and cooldown. Each segment in 'blocks' is either a standalone step (omit 'steps' key — provide goal_type/goal_value/targets directly, with optional purpose defaulting to 'work') or an interval block (include a 'steps' key with repeat_count and an ordered array of steps, each with purpose/goal/targets). Use standalone steps for continuous efforts; use interval blocks for repeated step cycles. For post-set rest between interval groups (rest that does not repeat with each rep), add a standalone recovery block after the interval block.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object(["type": .string("string"), "description": .string("Workout name shown on Apple Watch.")]),
                "warmup": .object([
                    "type": .string("object"),
                    "description": .string("Optional. Omit unless the user explicitly requests a warmup. Do not add one by default."),
                    "properties": .object([
                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                        "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, miles if distance. Omit for open.")]),
                        "target_heart_rate_bpm": .object(["type": .string("number")]),
                        "target_pace_seconds_per_mile": .object(["type": .string("number")])
                    ])
                ]),
                "blocks": .object([
                    "type": .string("array"),
                    "description": .string("Sequence of segments between warmup and cooldown. Each item is either a standalone step (goal_type/goal_value/targets, no 'steps' key) or an interval block ('steps' key required, with repeat_count and a steps array)."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "repeat_count": .object(["type": .string("number"), "description": .string("Interval blocks only. Repetitions (default 1).")]),
                            "purpose": .object(["type": .string("string"), "enum": .array([.string("work"), .string("recovery")]), "description": .string("Standalone steps only. Defaults to work.")]),
                            "display_name": .object(["type": .string("string"), "description": .string("Standalone steps only. Custom name shown for this step in the Fitness app.")]),
                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")]), "description": .string("Standalone steps only.")]),
                            "goal_value": .object(["type": .string("number"), "description": .string("Standalone steps only. Minutes if time, miles if distance. Omit for open.")]),
                            "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Standalone steps only.")]),
                            "target_pace_seconds_per_mile": .object(["type": .string("number"), "description": .string("Standalone steps only.")]),
                            "steps": .object([
                                "type": .string("array"),
                                "description": .string("Interval blocks only. Ordered list of steps per repetition."),
                                "items": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "purpose": .object(["type": .string("string"), "enum": .array([.string("work"), .string("recovery")])]),
                                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                                        "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, miles if distance. Omit for open.")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")]),
                                        "target_pace_seconds_per_mile": .object(["type": .string("number")])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ]),
                "cooldown": .object([
                    "type": .string("object"),
                    "description": .string("Optional. Omit unless the user explicitly requests a cooldown. Do not add one by default."),
                    "properties": .object([
                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                        "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, miles if distance. Omit for open.")]),
                        "target_heart_rate_bpm": .object(["type": .string("number")]),
                        "target_pace_seconds_per_mile": .object(["type": .string("number")])
                    ])
                ]),
                "scheduled_date": .object(["type": .string("string"), "description": .string("YYYY-MM-DD. Defaults to today.")]),
                "include_description": .object([
                    "type": .string("boolean"),
                    "description": .string("When true, include the human-readable workout description in the response. Default false."),
                    "default": .bool(false)
                ])
            ]),
            "required": .array([.string("title"), .string("blocks")])
        ])
    )

    static func handle(args: [String: Value], manager: WorkoutKitManager) async throws -> String {
        let title = args["title"]?.stringValue ?? ""
        guard !title.isEmpty else { return "Missing required parameter: title" }

        guard let blocksValue = args["blocks"],
              case .array(let blockArray) = blocksValue, !blockArray.isEmpty else {
            return "Missing required parameter: blocks (must be a non-empty array)"
        }

        let includeDescription = parseBoolean(named: "include_description", from: args) ?? false
        let scheduledDate = args["scheduled_date"]?.stringValue ?? isoToday()
        let warmup = parseStepSpec(from: args["warmup"])
        let cooldown = parseStepSpec(from: args["cooldown"])
        let blocks = blockArray.compactMap { parseBlockSpec(from: $0) }

        guard !blocks.isEmpty else {
            return "blocks array contained no valid block objects"
        }

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
            let description: String?
        }

        return try encodeToCompactJSON(Result(
            title: title,
            date: scheduledDate,
            description: includeDescription ? description : nil
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
        let steps: [(purpose: IntervalStep.Purpose, spec: StepSpec)] = stepsArray.compactMap { stepValue in
            guard case .object(let stepObj) = stepValue,
                  let spec = parseStepSpec(from: stepValue) else { return nil }
            let purpose: IntervalStep.Purpose = stepObj["purpose"]?.stringValue == "recovery" ? .recovery : .work
            return (purpose, spec)
        }
        guard !steps.isEmpty else { return nil }
        return BlockSpec(repeatCount: repeatCount, steps: steps)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return f
    }()

    private static func isoToday() -> String {
        dateFormatter.string(from: Date())
    }

    private static func parseDate(from iso: String) -> Date {
        dateFormatter.date(from: iso) ?? Date()
    }
}
