import MCP

func parseInteger(named name: String, from args: [String: Value]) -> Int? {
    args[name]?.intValue
}

func parseDays(from args: [String: Value], default defaultDays: Int = 7) -> Int {
    parseInteger(named: "days", from: args) ?? defaultDays
}
