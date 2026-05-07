import Foundation
import MCP

private let defaultQueryLimit = 50
private let maxQueryLimit = 500

func parseInteger(named name: String, from args: [String: Value]) -> Int? {
    args[name]?.intValue
}

func parseBoolean(named name: String, from args: [String: Value]) -> Bool? {
    args[name]?.boolValue
}

func parseBooleanOption(_ name: String, from args: [String: Value]) -> Bool {
    parseBoolean(named: name, from: args) ?? false
}

func parseDays(from args: [String: Value], default defaultDays: Int = 7) -> Int {
    parseInteger(named: "days", from: args) ?? defaultDays
}

func parseLimit(from args: [String: Value], default defaultLimit: Int = defaultQueryLimit, max maxLimit: Int = maxQueryLimit) -> Int {
    guard let requested = parseInteger(named: "limit", from: args), requested > 0 else {
        return defaultLimit
    }
    return min(requested, maxLimit)
}

func paginatedResponse<T: Encodable & Sendable>(from results: [T], limit: Int) -> PaginatedResults<T> {
    let limitedResults = Array(results.prefix(limit))
    return PaginatedResults(count: limitedResults.count, limit: limit, results: limitedResults)
}

func roundedValue(_ value: Double, places: Int = 2) -> Double {
    guard value.isFinite else { return value }
    let scale = pow(10.0, Double(places))
    return (value * scale).rounded() / scale
}
