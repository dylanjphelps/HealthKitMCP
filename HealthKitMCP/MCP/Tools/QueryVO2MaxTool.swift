import Foundation
import MCP

enum QueryVO2MaxTool {
    static let toolName = "query_vo2max"

    static let definition = Tool(
        name: toolName,
        description: "Returns the most recent VO2 max estimate recorded by Apple Watch.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        if let result = try await manager.queryVO2Max() {
            return try encodeToJSON(result)
        }
        return #"{"error":"No VO2 max data available"}"#
    }
}
