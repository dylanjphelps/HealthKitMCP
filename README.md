# HealthKit MCP

A native macOS MCP server that gives Claude Desktop access to your HealthKit fitness data and lets it schedule running workouts on your Apple Watch.

## Requirements

- macOS 15.0+
- Xcode 15+ (to build)
- Apple Developer Program membership
- Apple Watch paired to your iPhone (for `schedule_workout`)
- Claude Desktop

## Setup

### 1. Build the app

Open `HealthKitMCP.xcodeproj` in Xcode, set your Development Team in Signing & Capabilities, then build (`Cmd+B`).

### 2. Authorize HealthKit

Run the app without arguments (double-click or `Cmd+R` in Xcode). Click **Grant Access** and approve the HealthKit permission sheet. You only need to do this once.

### 3. Configure Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "/Applications/HealthKitMCP.app/Contents/MacOS/HealthKitMCP",
      "args": ["--mcp-stdio"]
    }
  }
}
```

Restart Claude Desktop.

## Available Tools

| Tool | Description |
|------|-------------|
| `query_workouts` | Running sessions — distance, pace, HR, calories |
| `query_activity_summary` | Daily steps, active calories, exercise minutes |
| `query_resting_heart_rate` | Daily resting heart rate (avg, min, max) |
| `query_vo2max` | Most recent VO2 max estimate |
| `schedule_workout` | Push an easy/tempo/interval run to Apple Watch |

## Testing with MCPJam Inspector

```bash
npx @mcpjam/inspector@latest
```

Command: `/path/to/HealthKitMCP.app/Contents/MacOS/HealthKitMCP`
Args: `--mcp-stdio`

Call each query tool and verify the JSON matches what you see in the Health app.

**Dry-run example** (validates without scheduling):

```json
{
  "workout_type": "tempo",
  "title": "Thursday Tempo",
  "warmup_minutes": 10,
  "tempo_distance_km": 5,
  "target_pace_seconds_per_km": 280,
  "cooldown_minutes": 10,
  "dry_run": true
}
```

Expected: `{"scheduled":false,"valid":true,"workout_description":"Tempo run: 10min warmup → 5.0km at 4:40/km → 10min cooldown"}`

## Revoking access

System Settings → Privacy & Security → Health → HealthKit MCP → toggle off any types.
