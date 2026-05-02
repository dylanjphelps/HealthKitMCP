// HealthKitMCP/App/AuthView.swift
import SwiftUI

struct AuthView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("WorkoutKit MCP")
                .font(.title2.bold())

            Text("Generates running workouts and Shortcuts URLs for scheduling to Apple Watch.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider()

            Text(Bundle.main.executableURL?.path ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}
