// HealthKitMCP/App/AuthView.swift
import SwiftUI

struct AuthView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("WorkoutKit MCP")
                .font(.title2.bold())

            Text("Schedules running workouts to Apple Watch via Claude Desktop.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Add to Claude Desktop:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(Bundle.main.executableURL?.path ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(30)
        .frame(width: 420, height: 280)
    }
}
