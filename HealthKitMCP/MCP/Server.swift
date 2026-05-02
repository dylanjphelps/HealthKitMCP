// HealthKitMCP/MCP/Server.swift
import Foundation
import MCP

actor HealthKitMCPServer {
    private let server: Server
    let transport: StatelessHTTPServerTransport   // non-private for HTTPServer
    private let healthKit: HealthKitManager
    private let workoutKit: WorkoutKitManager

    init() {
        // Disable origin validation: requests come from a Mac on the local network,
        // not localhost, so the default localhost-only check would reject them.
        // Use stateless transport: no session management, so reconnections always work.
        let pipeline = StandardValidationPipeline(validators: [
            OriginValidator.disabled,
            AcceptHeaderValidator(mode: .jsonOnly),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
        ])
        self.transport = StatelessHTTPServerTransport(validationPipeline: pipeline)
        self.healthKit = HealthKitManager()
        self.workoutKit = WorkoutKitManager()
        self.server = Server(
            name: "HealthKitMCP",
            version: "1.0.0",
            capabilities: Server.Capabilities(tools: .init(listChanged: false))
        )
    }

    func requestHealthKitAuthorization() async throws {
        try await healthKit.requestAuthorization()
    }

    func run() async throws {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: Self.allTools)
        }

        await server.withMethodHandler(CallTool.self) { [self] params in
            await self.handleToolCall(params)
        }

        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Dispatch

    private func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]
        do {
            let text: String
            switch params.name {
            case "schedule_workout":
                text = try await ScheduleWorkoutTool.handle(args: args)
            case QueryWorkoutsTool.toolName:
                text = try await QueryWorkoutsTool.handle(args: args, manager: healthKit)
            case QueryActivitySummaryTool.toolName:
                text = try await QueryActivitySummaryTool.handle(args: args, manager: healthKit)
            case QueryRestingHeartRateTool.toolName:
                text = try await QueryRestingHeartRateTool.handle(args: args, manager: healthKit)
            case QueryVO2MaxTool.toolName:
                text = try await QueryVO2MaxTool.handle(args: args, manager: healthKit)
            case QueryScheduledWorkoutsTool.toolName:
                text = try await QueryScheduledWorkoutsTool.handle(manager: workoutKit)
            case DeleteScheduledWorkoutTool.toolName:
                text = try await DeleteScheduledWorkoutTool.handle(args: args, manager: workoutKit)
            default:
                return CallTool.Result(
                    content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            return CallTool.Result(
                content: [.text(text: text, annotations: nil, _meta: nil)],
                isError: false
            )
        } catch {
            return CallTool.Result(
                content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }

    // MARK: - Tool Definitions

    private static var allTools: [Tool] {
        [
            scheduleWorkoutToolDefinition,
            QueryWorkoutsTool.definition,
            QueryActivitySummaryTool.definition,
            QueryRestingHeartRateTool.definition,
            QueryVO2MaxTool.definition,
            QueryScheduledWorkoutsTool.definition,
            DeleteScheduledWorkoutTool.definition,
        ]
    }

    private static var scheduleWorkoutToolDefinition: Tool {
        Tool(
            name: "schedule_workout",
            description: "Schedules a structured running workout directly to Apple Watch via WorkoutKit. Supports warmup, a sequence of segments, and cooldown. Each segment in 'blocks' is either a standalone step (omit 'work' key — just provide goal_type/goal_value/targets directly) or an interval block (include a 'work' key with repeat_count and optional rest/rest_after). Use standalone steps for continuous efforts; use interval blocks for repeated work/rest cycles.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object(["type": .string("string"), "description": .string("Workout name shown on Apple Watch.")]),
                    "warmup": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                            "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, miles if distance.")]),
                            "target_heart_rate_bpm": .object(["type": .string("number")])
                        ])
                    ]),
                    "blocks": .object([
                        "type": .string("array"),
                        "description": .string("Sequence of segments between warmup and cooldown. Each item is either a standalone step (goal_type/goal_value/targets, no 'work' key) or an interval block ('work' key required, with repeat_count and optional rest/rest_after)."),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "repeat_count": .object(["type": .string("number"), "description": .string("Interval blocks only. Repetitions (default 1).")]),
                                "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app. Standalone steps only (omit 'work' key).")]),
                                "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")]), "description": .string("Standalone steps only.")]),
                                "goal_value": .object(["type": .string("number"), "description": .string("Standalone steps only. Minutes if time, miles if distance.")]),
                                "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Standalone steps only.")]),
                                "target_pace_seconds_per_mile": .object(["type": .string("number"), "description": .string("Standalone steps only.")]),
                                "work": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                                        "goal_value": .object(["type": .string("number")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")]),
                                        "target_pace_seconds_per_mile": .object(["type": .string("number")])
                                    ])
                                ]),
                                "rest": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                                        "goal_value": .object(["type": .string("number"), "description": .string("Omit when goal_type is open.")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")])
                                    ])
                                ]),
                                "rest_after": .object([
                                    "type": .string("object"),
                                    "description": .string("A single recovery block inserted after all iterations of this block complete. Use for inter-set rest (e.g. 3 min between sets)."),
                                    "properties": .object([
                                        "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance"), .string("open")])]),
                                        "goal_value": .object(["type": .string("number"), "description": .string("Omit when goal_type is open.")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")])
                                    ])
                                ])
                            ])
                        ])
                    ]),
                    "cooldown": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "display_name": .object(["type": .string("string"), "description": .string("Custom name shown for this step in the Fitness app.")]),
                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                            "goal_value": .object(["type": .string("number")]),
                            "target_heart_rate_bpm": .object(["type": .string("number")])
                        ])
                    ]),
                    "scheduled_date": .object(["type": .string("string"), "description": .string("YYYY-MM-DD. Defaults to today.")])
                ]),
                "required": .array([.string("title"), .string("blocks")])
            ])
        )
    }
}
