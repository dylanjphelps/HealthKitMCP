import MCP

enum QuerySleepTool {
    static let toolName = "query_sleep"

    static let definition = Tool(
        name: toolName,
        description: "Returns nightly sleep summaries for the last N days. Each entry is keyed to the night's start date and includes total sleep minutes, time in bed, and a stage breakdown.",
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
                    "description": .string("Maximum number of sleep summaries to return. Default 50, max 500."),
                    "default": .int(50)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let results = (try await manager.querySleep(days: days)).map(\.rounded)
        return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
    }
}
