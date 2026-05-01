// HealthKitMCP/App/AuthView.swift
import SwiftUI
import HealthKit

struct AuthView: View {
    @State private var statusMessage = "HealthKit authorization status unknown."
    @State private var isAuthorized = false
    @State private var isRequesting = false

    private let healthKit = HealthKitManager()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isAuthorized ? "heart.fill" : "heart")
                .font(.system(size: 48))
                .foregroundColor(isAuthorized ? .green : .secondary)

            Text("HealthKit MCP")
                .font(.title2.bold())

            Text(statusMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !isAuthorized {
                Button(isRequesting ? "Requesting…" : "Grant Access") {
                    requestAuth()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting)
            }
        }
        .padding(30)
        .frame(width: 420, height: 280)
        .task { await checkStatus() }
    }

    private func checkStatus() async {
        isAuthorized = await healthKit.isAuthorized()
        statusMessage = isAuthorized
            ? "Authorized. Claude Desktop can now query your health data."
            : "Grant access so Claude Desktop can read your HealthKit data."
    }

    private func requestAuth() {
        isRequesting = true
        Task {
            do {
                try await healthKit.requestAuthorization()
                await checkStatus()
            } catch {
                statusMessage = "Authorization failed: \(error.localizedDescription)"
            }
            isRequesting = false
        }
    }
}
