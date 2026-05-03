import Foundation
import MCP

enum QueryWorkoutsTool {
    static let toolName = "query_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns running sessions for the last N days. Each session includes date, duration, distance, pace, heart rate, calories, elevation, power, and cadence. Also includes per-mile split pacing (splits) and per-interval breakdown for structured or lapped workouts (intervals). Splits assume mile auto-lap; intervals are richest for WorkoutKit-planned sessions.",
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
        let results = try await manager.queryWorkouts(days: days)
        return try encodeToJSON(results)
    }
}
