# HealthKit MCP

An iOS app that gives Claude Desktop access to your HealthKit fitness data and lets Claude schedule running workouts on your Apple Watch — over your local network.

## Requirements

- iPhone with iOS 18.0+ and Health app data
- Mac with Claude Desktop
- Node.js (for mcp-remote bridge)
- Xcode (any recent version) + a free Apple ID
- Both devices on the same Wi-Fi network
- Apple Watch paired to your iPhone (for workout scheduling)

## Setup

### 1. Build and install

Open `HealthKitMCP.xcodeproj` in Xcode, select your iPhone as the run destination, set your signing team (any free Apple ID works), then run (`Cmd+R`). Trust the developer certificate on your iPhone when prompted (Settings → General → VPN & Device Management).

### 2. Grant access

Open the app on your iPhone and tap **Grant HealthKit Access**. Approve all categories in the system sheet.

### 3. Configure Claude Desktop

The app displays the URL. Add it to `~/Library/Application Support/Claude/claude_desktop_config.json` under `mcpServers`, using `mcp-remote` to bridge Claude Desktop's stdio transport to the app's HTTP endpoint:

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "npx",
      "args": ["mcp-remote", "http://192.168.1.x:8080/mcp", "--allow-http"]
    }
  }
}
```

Replace `192.168.1.x` with the address the app displays. The `--allow-http` flag is required because the app serves over local HTTP (not HTTPS). Restart Claude Desktop.

### 4. Use Claude

Keep the app open on your iPhone while using Claude Desktop. Claude will connect automatically. The app uses Streamable HTTP for robust communication over your local network.

## Available tools

| Tool | Description |
|------|-------------|
| `query_workouts` | Running sessions — distance, pace, HR, calories, elevation, power, cadence, splits, and intervals. Returns summaries by default; use `include_splits`, `include_intervals`, `include_steps` for detailed data. Default limit: 50, max: 500. Pagination supported. |
| `query_elevation` | Elevation gain and loss for each running workout. Uses native HealthKit metadata (barometric altimeter) when available, falls back to route-based GPS computation for older workouts. Default limit: 50, max: 500. Pagination supported. |
| `query_heart_rate_zones` | Time spent in each heart rate zone per running workout. Default: 5 zones based on max HR of 185 bpm. Supports custom zone boundaries. Default limit: 50, max: 500. Pagination supported. |
| `query_activity_summary` | Daily steps, active calories, exercise minutes. Default limit: 50, max: 500. Pagination supported. |
| `query_resting_heart_rate` | Daily resting HR (avg, min, max). Default limit: 50, max: 500. Pagination supported. |
| `query_hrv` | Daily heart rate variability — SDNN avg, min, max in milliseconds. Default limit: 50, max: 500. Pagination supported. |
| `query_sleep` | Nightly sleep summaries — total sleep, time in bed, and stage breakdown (REM, core, deep, awake). Default limit: 50, max: 500. Pagination supported. |
| `query_body_mass` | Daily body weight in pounds (averaged across weigh-ins). Default limit: 50, max: 500. Pagination supported. |
| `query_vo2max` | Most recent VO2 max estimate |
| `schedule_workout` | Push a structured run directly to Apple Watch. Use `include_description` for verbose output. |
| `query_scheduled_workouts` | List upcoming workouts scheduled to Apple Watch. Default limit: 50, max: 500. Pagination supported. |
| `delete_scheduled_workout` | Remove a scheduled workout by index |

## Re-signing

Sideloaded apps expire every 7 days. Reconnect your iPhone and hit `Cmd+R` in Xcode to renew. [AltStore](https://altstore.io) can automate this.

## Revoking access

Settings → Privacy & Security → Health → HealthKit MCP → toggle off any types.
