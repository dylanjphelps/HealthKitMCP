import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: MCPService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("HealthKit MCP")
                .font(.title2.bold())

            Divider()

            // Server status
            HStack {
                Circle()
                    .fill(service.isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(service.isRunning ? "Server running" : "Server stopped")
                    .foregroundStyle(.secondary)
            }

            if !service.serverAddress.isEmpty {
                VStack(spacing: 4) {
                    Text("Claude Desktop config:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(#"{"url": "\#(service.serverAddress)"}"#)
                        .font(.system(.caption2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            UIPasteboard.general.string = #"{"url": "\#(service.serverAddress)"}"#
                        }
                }
            }

            Divider()

            Button(service.healthKitAuthorized ? "HealthKit: Authorized" : "Grant HealthKit Access") {
                service.requestHealthKitAuth()
            }
            .buttonStyle(.bordered)
            .disabled(service.healthKitAuthorized)

            Button(service.workoutKitAuthorized ? "Workout Scheduling: Authorized" : "Grant Workout Scheduling Access") {
                service.requestWorkoutKitAuth()
            }
            .buttonStyle(.bordered)
            .disabled(service.workoutKitAuthorized)

            Spacer()

            Text("Keep this app open while using Claude.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
