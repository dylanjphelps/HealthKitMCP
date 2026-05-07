# Squad Team

> HealthKitMCP — iOS app exposing HealthKit data to Claude Desktop via a local-network MCP server. Swift, iOS 18+, actors for concurrency, WorkoutKit integration.

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Luffy | Lead | `.squad/agents/luffy/charter.md` | 🏗️ Active |
| Franky | iOS Dev | `.squad/agents/franky/charter.md` | 📱 Active |
| Robin | MCP Dev | `.squad/agents/robin/charter.md` | 🔧 Active |
| Usopp | Tester | `.squad/agents/usopp/charter.md` | 🧪 Active |
| Nami | Tech Writer | `.squad/agents/nami/charter.md` | 📝 Active |
| Scribe | Session Logger | `.squad/agents/scribe/charter.md` | 📋 Active |
| Ralph | Work Monitor | — | 🔄 Monitor |

## Project Context

- **Project:** HealthKitMCP
- **Description:** iOS app that exposes HealthKit data to Claude Desktop via a local-network MCP server with WorkoutKit integration for scheduling structured running workouts to Apple Watch.
- **Language:** Swift 5.9
- **Platform:** iOS 18.0+
- **Build System:** XcodeGen (project.yml)
- **Key Frameworks:** HealthKit, WorkoutKit, MCP SDK (swift-sdk), Network (NWListener)
- **Architecture:** Actors (MCPService → HealthKitMCPServer → HealthKitManager/WorkoutKitManager), SwiftUI
- **User:** Dylan
- **Created:** 2026-05-07
