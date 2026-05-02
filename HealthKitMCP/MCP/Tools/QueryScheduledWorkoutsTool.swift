import Foundation
import MCP

enum QueryScheduledWorkoutsTool {
    static let toolName = "query_scheduled_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns all upcoming workouts scheduled to Apple Watch via WorkoutKit. Each item includes an index (use this to delete), date, title, and type.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static func handle(manager: WorkoutKitManager) async throws -> String {
        let results = try await manager.queryScheduled()
        return try encodeToJSON(results)
    }
}
