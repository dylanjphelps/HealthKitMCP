import Foundation
import MCP

enum QueryWorkoutsTool {
    static let toolName = "query_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns running sessions for the last N days. Includes date, duration, distance, pace, average heart rate, and calories.",
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

    static func parseDays(from args: [String: Value]) -> Int {
        args["days"]?.intValue ?? 7
    }

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let results = try await manager.queryWorkouts(days: days)
        return try encodeToJSON(results)
    }
}
