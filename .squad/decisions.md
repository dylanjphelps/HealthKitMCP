# Squad Decisions

## Active Decisions

### Architecture Layering (2026-05-07)
**Source:** Luffy Architecture Review

Keep the documented actor layering (`MCPService` → `HealthKitMCPServer` → managers) as the project standard. Enforce strict argument parsing for schema-declared integers, and keep HTTP/MCP reconnect logic changes behind team review because the current behavior depends on coordinated generation tracking and transport replacement.

**Implementation notes:**
- Cleanup applied: strict integer parsing for integer-only tool arguments
- Removal of obvious unused imports in tool files
- Serial queue usage inside `HTTPServer`
- Removal of redundant target settings from `project.yml`
- Discussion item: the reconnect/reset flow is the main architectural hotspot; spans `MCPService.swift` and `HTTPServer.swift`, so larger refactors should be reviewed as architecture work

### MCP Tool Handler Standard (2026-05-07)
**Source:** Robin MCP Review

- Keep MCP tool handlers on a uniform enum shape with `toolName`, `definition`, and `handle(args:manager:)`, even for tools that ignore arguments today
- Treat malformed raw HTTP requests at the adapter layer as explicit `400 Bad Request` responses instead of silently closing the socket

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
