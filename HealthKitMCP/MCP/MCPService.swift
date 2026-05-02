import Foundation
import Network

@MainActor
final class MCPService: ObservableObject {
    @Published var isRunning = false
    @Published var serverAddress = ""
    @Published var healthKitAuthorized = false

    private var mcpServer: HealthKitMCPServer?
    private var httpServer: HTTPServer?
    private var serverTask: Task<Void, Error>?

    func start() {
        guard !isRunning else { return }

        let server = HealthKitMCPServer()
        let http = HTTPServer(transport: server.transport)
        mcpServer = server
        httpServer = http

        serverTask = Task {
            do {
                try await http.start()
                serverAddress = "http://\(localIPAddress() ?? "?"):8080/mcp"
                isRunning = true
                try await server.run()
            } catch {
                isRunning = false
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        Task { await httpServer?.stop() }
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
                    if ip.hasPrefix("192.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                        address = ip
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return address
    }
}
