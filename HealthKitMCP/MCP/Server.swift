// HealthKitMCP/MCP/Server.swift
import Foundation
import MCP

actor HealthKitMCPServer {
    private let server: Server
    let transport: StatefulHTTPServerTransport   // non-private for HTTPServer
    private let healthKit: HealthKitManager

    init() {
        // Disable origin validation: requests come from a Mac on the local network,
        // not localhost, so the default localhost-only check would reject them.
        let pipeline = StandardValidationPipeline(validators: [
            OriginValidator.disabled,
            AcceptHeaderValidator(mode: .sseRequired),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
            SessionValidator(),
        ])
        self.transport = StatefulHTTPServerTransport(validationPipeline: pipeline)
        self.healthKit = HealthKitManager()
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
        ]
    }

    private static var scheduleWorkoutToolDefinition: Tool {
        Tool(
            name: "schedule_workout",
            description: "Schedules a structured running workout directly to Apple Watch via WorkoutKit. Supports warmup, interval blocks with work/rest steps, and cooldown. Each step can target heart rate or pace.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object(["type": .string("string"), "description": .string("Workout name shown on Apple Watch.")]),
                    "warmup": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                            "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, km if distance.")]),
                            "target_heart_rate_bpm": .object(["type": .string("number")])
                        ])
                    ]),
                    "blocks": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "repeat_count": .object(["type": .string("number"), "description": .string("Repetitions (default 1).")]),
                                "work": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                        "goal_value": .object(["type": .string("number")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")]),
                                        "target_pace_seconds_per_km": .object(["type": .string("number")])
                                    ])
                                ]),
                                "rest": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                        "goal_value": .object(["type": .string("number")]),
                                        "target_heart_rate_bpm": .object(["type": .string("number")])
                                    ])
                                ])
                            ])
                        ])
                    ]),
                    "cooldown": .object([
                        "type": .string("object"),
                        "properties": .object([
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
