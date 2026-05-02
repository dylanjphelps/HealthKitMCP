import SwiftUI

@main
struct HealthKitMCPApp: App {
    @StateObject private var service = MCPService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
                .onAppear { service.start() }
        }
    }
}
