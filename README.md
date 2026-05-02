# HealthKit MCP

An iOS app that gives Claude Desktop access to your HealthKit fitness data and lets Claude schedule running workouts on your Apple Watch — over your local network.

## Requirements

- iPhone with iOS 17.0+ and Health app data
- Mac with Claude Desktop
- Xcode (any recent version) + a free Apple ID
- Both devices on the same Wi-Fi network
- Apple Watch paired to your iPhone (for workout scheduling)

## Setup

### 1. Build and install

Open `HealthKitMCP.xcodeproj` in Xcode, select your iPhone as the run destination, set your signing team (any free Apple ID works), then run (`Cmd+R`). Trust the developer certificate on your iPhone when prompted (Settings → General → VPN & Device Management).

### 2. Grant access

Open the app on your iPhone and tap **Grant HealthKit Access**. Approve all categories in the system sheet.

### 3. Configure Claude Desktop

The app displays the config snippet. Copy it and paste into `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "/opt/homebrew/bin/npx",
      "args": [
        "mcp-remote@latest",
        "http://192.168.1.0:8080/mcp",
        "--allow-http"
      ]
    }
  }
}
```

Replace the address with what the app shows. Restart Claude Desktop.

### 4. Use Claude

Keep the app open on your iPhone while using Claude Desktop. Claude will connect automatically.

## Available tools

| Tool | Description |
|------|-------------|
| `query_workouts` | Running sessions — distance, pace, avg HR, calories |
| `query_activity_summary` | Daily steps, active calories, exercise minutes |
| `query_resting_heart_rate` | Daily resting HR (avg, min, max) |
| `query_vo2max` | Most recent VO2 max estimate |
| `schedule_workout` | Push a structured run directly to Apple Watch |
| `query_scheduled_workouts` | List upcoming workouts scheduled to Apple Watch |
| `delete_scheduled_workout` | Remove a scheduled workout by index |

## Re-signing

Sideloaded apps expire every 7 days. Reconnect your iPhone and hit `Cmd+R` in Xcode to renew. [AltStore](https://altstore.io) can automate this.

## Revoking access

Settings → Privacy & Security → Health → HealthKit MCP → toggle off any types.
