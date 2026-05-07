import MCP

enum QueryScheduledWorkoutsTool {
    static let toolName = "query_scheduled_workouts"

    static let definition = Tool(
        name: toolName,
        description: "Returns all upcoming workouts scheduled to Apple Watch via WorkoutKit. Each item includes an index (use this to delete), date, title, type, and full step structure (warmup, interval blocks with repeat counts and work/recovery steps, cooldown). Each step includes goal type (time/distance/open), goal value (minutes or miles), and optional target pace or heart rate.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static func handle(args _: [String: Value], manager: WorkoutKitManager) async throws -> String {
        let results = try await manager.queryScheduled()
        return try encodeToJSON(results)
    }
}
