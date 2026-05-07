import MCP

enum QueryBodyMassTool {
    static let toolName = "query_body_mass"

    static let definition = Tool(
        name: toolName,
        description: "Returns daily body weight for the last N days. Each entry includes the date and weight in pounds (averaged across all weigh-ins that day).",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Number of days to look back. Default 30."),
                    "default": .int(30)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args, default: 30)
        let results = try await manager.queryBodyMass(days: days)
        return try encodeToJSON(results)
    }
}
