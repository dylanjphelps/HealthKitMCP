import MCP

func parseDays(from args: [String: Value]) -> Int {
    args["days"]?.intValue ?? 7
}
