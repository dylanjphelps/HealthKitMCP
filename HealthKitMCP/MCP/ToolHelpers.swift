// HealthKitMCP/MCP/ToolHelpers.swift
import Foundation
import MCP

/// Parses optional start_date / end_date from MCP Value args.
/// Falls back to DateHelpers.defaultRange() if either is missing or unparseable.
func parseDateRange(args: [String: Value]) -> (start: Date, end: Date) {
    let defaults = DateHelpers.defaultRange()
    let start: Date
    let end: Date

    if let s = args["start_date"]?.stringValue, let parsed = DateHelpers.parse(s) {
        start = parsed
    } else {
        start = defaults.start
    }

    if let e = args["end_date"]?.stringValue, let parsed = DateHelpers.parse(e) {
        end = parsed
    } else {
        end = defaults.end
    }

    return (start, end)
}
