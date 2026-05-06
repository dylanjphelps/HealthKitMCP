import MCP

func parseDays(from args: [String: Value], default defaultDays: Int = 7) -> Int {
    args["days"]?.intValue ?? defaultDays
}
