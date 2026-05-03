import Foundation
import MCP

enum QueryRestingHeartRateTool {
    static let toolName = "query_resting_heart_rate"

    static let definition = Tool(
        name: toolName,
        description: "Returns daily resting heart rate for the last N days. Includes average, min, and max BPM per day.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Number of days to look back. Default 7."),
                    "default": .int(7)
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let results = try await manager.queryRestingHeartRate(days: days)
        return try encodeToJSON(results)
    }
}
