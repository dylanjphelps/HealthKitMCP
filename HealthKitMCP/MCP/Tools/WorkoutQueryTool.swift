// HealthKitMCP/MCP/Tools/WorkoutQueryTool.swift
import Foundation
import MCP

enum WorkoutQueryTool {
    static func handle(
        args: [String: Value],
        healthKit: HealthKitManager
    ) async throws -> String {
        let (start, end) = parseDateRange(args: args)
        let result = try await healthKit.queryWorkouts(from: start, to: end)
        switch result {
        case .success(let records):
            return try encodeToJSON(records)
        case .failure(let e):
            return e.message
        }
    }
}
