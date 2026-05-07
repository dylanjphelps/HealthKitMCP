import MCP

enum QueryWorkoutsTool {
    static let toolName = "query_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns running sessions for the last N days. By default each result is a compact summary with date, type, duration, distance, and calories. Set include_splits to true for the full workout payload, including splits and interval details.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Number of days to look back. Default 7."),
                    "default": .int(7)
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of workouts to return. Default 50, max 500."),
                    "default": .int(50)
                ]),
                "include_splits": .object([
                    "type": .string("boolean"),
                    "description": .string("When true, return the full workout payload including splits and interval detail. Default false."),
                    "default": .bool(false)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let includeSplits = parseBoolean(named: "include_splits", from: args) ?? false
        let results = (try await manager.queryWorkouts(days: days)).map(\.rounded)

        if includeSplits {
            return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
        }

        let summaries = results.map(\.summary)
        return try encodeToCompactJSON(paginatedResponse(from: summaries, limit: limit))
    }
}
