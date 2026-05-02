import Foundation
import Network
import WorkoutKit

@MainActor
final class MCPService: ObservableObject {
    @Published var isRunning = false
    @Published var serverAddress = ""
    @Published var healthKitAuthorized = false
    @Published var workoutKitAuthorized = false

    private var mcpServer: HealthKitMCPServer?
    private var httpServer: HTTPServer?
    private var serverTask: Task<Void, Error>?

    func start() {
        guard !isRunning else { return }
        Task {
            workoutKitAuthorized = await WorkoutScheduler.shared.authorizationState == .authorized
        }
        Task {
            healthKitAuthorized = await !HealthKitManager.needsAuthorization()
        }

        serverTask = Task {
            var currentServer = HealthKitMCPServer()
            let http = HTTPServer(transport: currentServer.transport)
            mcpServer = currentServer
            httpServer = http

            do {
                try await http.start()
                serverAddress = "http://\(localIPAddress() ?? "?"):8080/mcp"
                isRunning = true

                // Provide a resetter so HTTPServer can spin up a fresh MCP server
                // when a reconnecting client's initialize is rejected as "already initialized".
                await http.setServerResetter { [weak http] in
                    let next = HealthKitMCPServer()
                    guard let http else { return }
                    await http.updateTransport(next.transport)
                    Task { try? await next.run() }
                }

                while !Task.isCancelled {
                    do { try await currentServer.run() } catch {}
                    guard !Task.isCancelled else { break }
                    let next = HealthKitMCPServer()
                    await http.updateTransport(next.transport)
                    currentServer = next
                    mcpServer = next
                }
            } catch {
                isRunning = false
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        let http = httpServer
        Task { await http?.stop() }
        mcpServer = nil
        httpServer = nil
        isRunning = false
        serverAddress = ""
    }

    func requestHealthKitAuth() {
        Task {
            try? await mcpServer?.requestHealthKitAuthorization()
            healthKitAuthorized = true
        }
    }

    func requestWorkoutKitAuth() {
        Task {
            let result = await WorkoutScheduler.shared.requestAuthorization()
            workoutKitAuthorized = result == .authorized
        }
    }

    private func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            if let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET),
               flags & IFF_UP != 0,
               flags & IFF_LOOPBACK == 0
            {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: host)
                    if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                        address = ip
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return address
    }
}
