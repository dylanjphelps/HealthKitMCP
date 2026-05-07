import MCP

enum QueryActivitySummaryTool {
    static let toolName = "query_activity_summary"

    static let definition = Tool(
        name: toolName,
        description: "Returns daily activity summaries for the last N days. Includes steps, active calories, and exercise minutes.",
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
                    "description": .string("Maximum number of daily summaries to return. Default 50, max 500."),
                    "default": .int(50)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let results = (try await manager.queryActivitySummary(days: days)).map(\.rounded)
        return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
    }
}
