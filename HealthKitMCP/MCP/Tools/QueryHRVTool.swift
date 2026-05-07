import MCP

enum QueryHRVTool {
    static let toolName = "query_hrv"

    static let definition = Tool(
        name: toolName,
        description: "Returns daily heart rate variability (HRV) for the last N days. Each entry includes average, min, and max SDNN in milliseconds.",
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
                    "description": .string("Maximum number of daily HRV rows to return. Default 50, max 500."),
                    "default": .int(50)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let results = (try await manager.queryHRV(days: days)).map(\.rounded)
        return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
    }
}
