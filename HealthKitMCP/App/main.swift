// HealthKitMCP/App/main.swift
import AppKit
import Foundation

if CommandLine.arguments.contains("--mcp-stdio") {
    let healthKit = HealthKitManager()
    let mcpServer = HealthKitMCPServer(healthKit: healthKit)
    RunLoop.main.perform {
        Task {
            do {
                try await mcpServer.run()
            } catch {
                fputs("HealthKitMCP server error: \(error)\n", stderr)
                exit(1)
            }
            exit(0)
        }
    }
    RunLoop.main.run()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
