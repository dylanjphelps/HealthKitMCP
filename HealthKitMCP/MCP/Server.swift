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
                description: "Schedule a running workout using WorkoutKit. Supports easy, tempo, and interval workouts. Use dry_run=true to validate without scheduling.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "workout_type": .object([
                            "type": .string("string"),
                            "enum": .array([.string("easy"), .string("tempo"), .string("interval")]),
                            "description": .string("Type of workout to schedule.")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Display name for the workout.")
                        ]),
                        "goal_type": .object([
                            "type": .string("string"),
                            "enum": .array([.string("distance"), .string("time"), .string("open")]),
                            "description": .string("Workout goal type: distance (km), time (minutes), or open (no goal).")
                        ]),
                        "goal_value": .object([
                            "type": .string("number"),
                            "description": .string("Goal value: km if goal_type is distance, minutes if time.")
                        ]),
                        "warmup_minutes": .object([
                            "type": .string("number"),
                            "description": .string("(easy/tempo) Warmup duration in minutes.")
                        ]),
                        "tempo_distance_km": .object([
                            "type": .string("number"),
                            "description": .string("(tempo only) Tempo segment distance in km.")
                        ]),
                        "target_pace_seconds_per_km": .object([
                            "type": .string("number"),
                            "description": .string("(tempo/interval) Target pace in seconds per km.")
                        ]),
                        "cooldown_minutes": .object([
                            "type": .string("number"),
                            "description": .string("(easy/tempo) Cooldown duration in minutes.")
                        ]),
                        "repeat_count": .object([
                            "type": .string("number"),
                            "description": .string("(interval only) Number of work/rest repetitions.")
                        ]),
                        "work_distance_meters": .object([
                            "type": .string("number"),
                            "description": .string("(interval only) Work interval distance in meters.")
                        ]),
                        "rest_distance_meters": .object([
                            "type": .string("number"),
                            "description": .string("(interval only) Rest interval distance in meters.")
                        ]),
                        "dry_run": .object([
                            "type": .string("boolean"),
                            "description": .string("If true, validate and describe the workout without scheduling it. Defaults to false.")
                        ])
                    ]),
                    "required": .array([.string("workout_type"), .string("title")])
                ])
            )
        ]
    }
}
