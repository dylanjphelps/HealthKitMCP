import Foundation
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
    private var serverGeneration = 0

    func start() {
        guard !isRunning else { return }
        Task { await refreshAuthorizationStatuses() }

        serverTask = Task {
            let initialServer = HealthKitMCPServer()
            let http = HTTPServer(transport: initialServer.transport)
            httpServer = http

            do {
                try await http.start()
                serverAddress = "http://\(localIPAddress() ?? "?"):\(HTTPServer.port)/mcp"
                isRunning = true
                await launch(server: initialServer, on: http)

                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(3600))
                }
            } catch {
                serverGeneration += 1
                isRunning = false
                mcpServer = nil
                httpServer = nil
                serverAddress = ""
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
        serverGeneration += 1
        let http = httpServer
        let server = mcpServer
        Task { await http?.stop() }
        Task { await server?.transport.disconnect() }
        mcpServer = nil
        httpServer = nil
        isRunning = false
        serverAddress = ""
    }

    func requestHealthKitAuth() {
        Task {
            do {
                guard let mcpServer else {
                    await refreshAuthorizationStatuses()
                    return
                }
                try await mcpServer.requestHealthKitAuthorization()
            } catch {
                // Refresh the derived UI state instead of assuming authorization succeeded.
            }
            await refreshAuthorizationStatuses()
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

    private func refreshAuthorizationStatuses() async {
        async let workoutAuthorization = WorkoutScheduler.shared.authorizationState
        async let needsHealthAuthorization = HealthKitManager.needsAuthorization()

        workoutKitAuthorized = await workoutAuthorization == .authorized
        healthKitAuthorized = await !needsHealthAuthorization
    }

    private func launch(server: HealthKitMCPServer, on http: HTTPServer) async {
        serverGeneration += 1
        let generation = serverGeneration
        mcpServer = server
        await http.updateTransport(server.transport)

        Task { [weak self] in
            do {
                try await server.run()
            } catch {}

            guard let self else { return }
            await self.restartServerIfNeeded(for: generation, on: http)
        }
    }

    private func replaceServer(on http: HTTPServer) async {
        let previousServer = mcpServer
        let nextServer = HealthKitMCPServer()
        await launch(server: nextServer, on: http)
        await previousServer?.transport.disconnect()
    }

    private func restartServerIfNeeded(for generation: Int, on http: HTTPServer) async {
        guard isRunning, serverGeneration == generation else { return }
        await replaceServer(on: http)
    }
}
