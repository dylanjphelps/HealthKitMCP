// HealthKitMCP/MCP/Tools/HeartRateTool.swift
import Foundation
import MCP

enum HeartRateTool {
    static func handle(
        args: [String: Value],
        healthKit: HealthKitManager
    ) async throws -> String {
        let (start, end) = parseDateRange(args: args)
        let result = try await healthKit.queryRestingHeartRate(from: start, to: end)
        switch result {
        case .success(let records):
            return try encodeToJSON(records)
        case .failure(let message):
            return message
        }
    }
}
