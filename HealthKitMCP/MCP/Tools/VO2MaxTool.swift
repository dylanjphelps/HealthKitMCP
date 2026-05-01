// HealthKitMCP/MCP/Tools/VO2MaxTool.swift
import Foundation
import MCP

enum VO2MaxTool {
    static func handle(healthKit: HealthKitManager) async throws -> String {
        let result = try await healthKit.queryVO2Max()
        switch result {
        case .success(let record):
            return try encodeToJSON(record)
        case .failure(let e):
            return e.message
        }
    }
}
