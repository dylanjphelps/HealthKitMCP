import MCP

enum QueryHeartRateZonesTool {
    static let toolName = "query_heart_rate_zones"

    static let defaultBoundaries: [Double] = [130, 149, 158, 168]
    static let defaultLabels = ["Recovery", "Easy Aerobic", "Tempo", "Threshold", "VO2max+"]

    static let definition = Tool(
        name: toolName,
        description: "Returns time spent in each heart rate zone for each running workout in the last N days. Default zones are based on max HR of 185 bpm: Zone 1 Recovery (< 130), Zone 2 Easy Aerobic (130-148), Zone 3 Tempo (149-157), Zone 4 Threshold (158-167), Zone 5 VO2max+ (>= 168). Provide custom zone_boundaries to override.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Number of days to look back. Default 7."),
                    "default": .int(7)
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of workouts to return. Default 50, max 500."),
                    "default": .int(50)
                ]),
                "zone_boundaries": .object([
                    "type": .string("array"),
                    "description": .string("Custom heart rate zone boundaries in BPM, ascending. For example [120, 150, 170] creates 4 zones: < 120, 120-149, 150-169, >= 170. Default [130, 149, 158, 168] creates 5 zones based on max HR of 185."),
                    "items": .object([
                        "type": .string("integer")
                    ])
                ])
            ])
        ])
    )

    static func handle(args: [String: Value], manager: HealthKitManager) async throws -> String {
        let days = parseDays(from: args)
        let limit = parseLimit(from: args)
        let boundaries = parseZoneBoundaries(from: args)
        let results = (try await manager.queryHeartRateZones(days: days, boundaries: boundaries)).map(\.rounded)
        return try encodeToCompactJSON(paginatedResponse(from: results, limit: limit))
    }

    static func parseZoneBoundaries(from args: [String: Value]) -> [Double]? {
        guard let array = args["zone_boundaries"]?.arrayValue else { return nil }
        let values = array.compactMap { v -> Double? in
            if let d = v.doubleValue { return d }
            if let i = v.intValue { return Double(i) }
            return nil
        }
        guard !values.isEmpty else { return nil }
        return values.sorted()
    }
}
