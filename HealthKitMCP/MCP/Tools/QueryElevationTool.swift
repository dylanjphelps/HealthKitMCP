import MCP

enum QueryElevationTool {
    static let toolName = "query_elevation"

    static let definition = Tool(
        name: toolName,
        description: "Returns elevation gain and loss for each running workout in the last N days. Uses native HealthKit workout metadata (barometric altimeter) when available, falls back to route-based GPS computation for older workouts. Returns null if neither source has data.",
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
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let results = (try await manager.queryElevation(days: days)).map(\.rounded)
        return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
    }
}
