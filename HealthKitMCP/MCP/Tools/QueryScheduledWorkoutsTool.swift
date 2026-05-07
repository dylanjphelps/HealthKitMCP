import MCP

enum QueryScheduledWorkoutsTool {
    static let toolName = "query_scheduled_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns upcoming WorkoutKit workouts. By default each result is a summary with index, date, title, and type. Set include_steps for warmup/cooldown details and include_intervals for interval block details.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of scheduled workouts to return. Default 50, max 500."),
                    "default": .int(50)
                ]),
                "include_steps": .object([
                    "type": .string("boolean"),
                    "description": .string("When true, include warmup and cooldown step details. Default false."),
                    "default": .bool(false)
                ]),
                "include_intervals": .object([
                    "type": .string("boolean"),
                    "description": .string("When true, include interval block details. Default false."),
                    "default": .bool(false)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: WorkoutKitManager) async throws -> String {
        let limit = parseLimit(from: args)
        let includeSteps = parseBoolean(named: "include_steps", from: args) ?? false
        let includeIntervals = parseBoolean(named: "include_intervals", from: args) ?? false
        let results = (try await manager.queryScheduled()).map(\.rounded)

        if includeSteps || includeIntervals {
            let detailed = results.map { $0.detailed(includeSteps: includeSteps, includeIntervals: includeIntervals) }
            return try encodeToCompactJSON(paginatedResponse(from: detailed, limit: limit))
        }

        let summaries = results.map(\.summary)
        return try encodeToCompactJSON(paginatedResponse(from: summaries, limit: limit))
    }
}
