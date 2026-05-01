// HealthKitMCP/MCP/Server.swift
import Foundation
import MCP

/// HealthKitMCPServer initializes the MCP server, registers all 5 tool handlers,
/// and routes tool calls to the appropriate handler functions.
actor HealthKitMCPServer {
    private let server: Server
    private let healthKit: HealthKitManager
    private let transport: StdioTransport

    init(healthKit: HealthKitManager) {
        self.healthKit = healthKit
        self.transport = StdioTransport()
        self.server = Server(
            name: "HealthKitMCP",
            version: "1.0.0",
            capabilities: Server.Capabilities(
                tools: .init(listChanged: false)
            )
        )
    }

    func run() async throws {
        // Register tools/list handler
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: Self.allTools)
        }

        // Register tools/call handler
        await server.withMethodHandler(CallTool.self) { [self] params in
            return await self.handleToolCall(params)
        }

        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Dispatch

    private func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]
        do {
            let text: String
            switch params.name {
            case "query_workouts":
                text = try await WorkoutQueryTool.handle(args: args, healthKit: healthKit)
            case "query_activity_summary":
                text = try await ActivitySummaryTool.handle(args: args, healthKit: healthKit)
            case "query_resting_heart_rate":
                text = try await HeartRateTool.handle(args: args, healthKit: healthKit)
            case "query_vo2max":
                text = try await VO2MaxTool.handle(healthKit: healthKit)
            case "schedule_workout":
                text = try await ScheduleWorkoutTool.handle(args: args)
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
            Tool(
                name: "query_workouts",
                description: "Query running workouts from HealthKit. Returns a JSON array of workout records.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in YYYY-MM-DD format. Defaults to 14 days ago.")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in YYYY-MM-DD format. Defaults to today.")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "query_activity_summary",
                description: "Query daily activity summaries (steps, active energy, exercise minutes) from HealthKit.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in YYYY-MM-DD format. Defaults to 14 days ago.")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in YYYY-MM-DD format. Defaults to today.")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "query_resting_heart_rate",
                description: "Query daily resting heart rate records from HealthKit.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "start_date": .object([
                            "type": .string("string"),
                            "description": .string("Start date in YYYY-MM-DD format. Defaults to 14 days ago.")
                        ]),
                        "end_date": .object([
                            "type": .string("string"),
                            "description": .string("End date in YYYY-MM-DD format. Defaults to today.")
                        ])
                    ]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "query_vo2max",
                description: "Query the most recent VO2 max measurement from HealthKit. No parameters required.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            Tool(
                name: "schedule_workout",
                description: "Schedule a running workout for today using WorkoutKit. Define the workout as an ordered list of blocks — each block is a set of work/rest steps repeated N times. Supports any workout structure: easy runs, intervals, tempo, hill repeats, or complex multi-phase sessions.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Workout name shown on Apple Watch.")
                        ]),
                        "warmup": .object([
                            "type": .string("object"),
                            "description": .string("Optional warmup step before the main blocks."),
                            "properties": .object([
                                "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, km if distance.")]),
                                "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Target HR center point (±5 BPM range alert).")])
                            ])
                        ]),
                        "blocks": .object([
                            "type": .string("array"),
                            "description": .string("Ordered workout blocks. Each block repeats its work/rest steps N times."),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "repeat_count": .object(["type": .string("number"), "description": .string("Repetitions (default 1 for single steps).")]),
                                    "work": .object([
                                        "type": .string("object"),
                                        "description": .string("Work step definition."),
                                        "properties": .object([
                                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                            "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, km if distance.")]),
                                            "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Target HR center point (±5 BPM range alert). Preferred over pace if both given.")]),
                                            "target_pace_seconds_per_km": .object(["type": .string("number"), "description": .string("Target pace in sec/km (±10 sec/km range alert).")])
                                        ])
                                    ]),
                                    "rest": .object([
                                        "type": .string("object"),
                                        "description": .string("Optional recovery step after each work step."),
                                        "properties": .object([
                                            "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                            "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, km if distance.")]),
                                            "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Optional HR target for recovery.")])
                                        ])
                                    ])
                                ])
                            ])
                        ]),
                        "cooldown": .object([
                            "type": .string("object"),
                            "description": .string("Optional cooldown step after the main blocks. Same shape as warmup."),
                            "properties": .object([
                                "goal_type": .object(["type": .string("string"), "enum": .array([.string("time"), .string("distance")])]),
                                "goal_value": .object(["type": .string("number"), "description": .string("Minutes if time, km if distance.")]),
                                "target_heart_rate_bpm": .object(["type": .string("number"), "description": .string("Target HR center point (±5 BPM range alert).")])
                            ])
                        ]),
                        "scheduled_date": .object([
                            "type": .string("string"),
                            "description": .string("Date to schedule the workout in YYYY-MM-DD format. Defaults to today.")
                        ]),
                        "dry_run": .object([
                            "type": .string("boolean"),
                            "description": .string("If true, validate and describe the workout without scheduling. Default false.")
                        ])
                    ]),
                    "required": .array([.string("title"), .string("blocks")])
                ])
            )
        ]
    }
}
