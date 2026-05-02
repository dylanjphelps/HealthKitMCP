import Foundation
import MCP

enum DeleteScheduledWorkoutTool {
    static let toolName = "delete_scheduled_workout"

    static let definition = Tool(
        name: toolName,
        description: "Deletes a scheduled workout from Apple Watch by its index. Call query_scheduled_workouts first to get the index.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "index": .object([
                    "type": .string("integer"),
                    "description": .string("The index of the workout to delete, from query_scheduled_workouts.")
                ])
            ]),
            "required": .array([.string("index")])
        ])
    )

    static func parseIndex(from args: [String: Value]) -> Int? {
        args["index"]?.intValue
    }

    static func handle(args: [String: Value], manager: WorkoutKitManager) async throws -> String {
        guard let index = parseIndex(from: args) else {
            return "Missing required parameter: index"
        }
        let deleted = try await manager.deleteScheduled(at: index)
        return try encodeToJSON(deleted)
    }
}
