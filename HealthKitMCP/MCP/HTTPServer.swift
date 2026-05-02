import Foundation
import Network
import MCP

actor HTTPServer {
    static let port: UInt16 = 8080

    private let transport: StatefulHTTPServerTransport
    private var listener: NWListener?

    init(transport: StatefulHTTPServerTransport) {
        self.transport = transport
    }

    // MARK: - Lifecycle

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            Task { await self.handleConnection(conn) }
        }

        listener.start(queue: .global())
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global())

        guard let rawData = await readCompleteRequest(from: connection),
              let request = Self.parseRequest(rawData) else {
            connection.cancel()
            return
        }

        let response = await transport.handleRequest(request)
        await writeResponse(response, to: connection)
    }

    // MARK: - Reading

    private func readCompleteRequest(from connection: NWConnection) async -> Data? {
        var buffer = Data()
        let sep = Data("\r\n\r\n".utf8)

        while true {
            guard let chunk = await receiveChunk(from: connection), !chunk.isEmpty else {
                // Connection closed or errored — only return data if no body was expected
                if let sepRange = buffer.range(of: sep) {
                    let headerBytes = buffer[..<sepRange.lowerBound]
                    let bodyStart = sepRange.upperBound
                    if let contentLength = Self.parseContentLength(from: headerBytes) {
                        // Body was expected but not fully received
                        return buffer.count >= bodyStart + contentLength ? Data(buffer[..<(bodyStart + contentLength)]) : nil
                    }
                }
                return buffer.isEmpty ? nil : buffer
            }
            buffer.append(chunk)

            guard let sepRange = buffer.range(of: sep) else { continue }

            let headerBytes = buffer[..<sepRange.lowerBound]
            let bodyStart = sepRange.upperBound

            if let contentLength = Self.parseContentLength(from: headerBytes) {
                if buffer.count >= bodyStart + contentLength {
                    return Data(buffer[..<(bodyStart + contentLength)])
                }
                // Need more data — continue loop
            } else {
                return buffer   // No body (GET, DELETE)
            }
        }
    }

    private func receiveChunk(from connection: NWConnection) async -> Data? {
        await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, _ in
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: isComplete ? Data() : nil)
                }
            }
        }
    }

    // MARK: - Writing

    private func writeResponse(_ response: HTTPResponse, to connection: NWConnection) async {
        switch response {
        case .stream(let sseStream, let headers):
            var header = "HTTP/1.1 200 OK\r\n"
            for (k, v) in headers { header += "\(k): \(v)\r\n" }
            header += "\r\n"
            await send(Data(header.utf8), to: connection)
            do {
                for try await chunk in sseStream {
                    await send(chunk, to: connection)
                }
            } catch {}
            connection.cancel()

        default:
            let body = response.bodyData ?? Data()
            var header = "HTTP/1.1 \(response.statusCode) \(statusText(response.statusCode))\r\n"
            for (k, v) in response.headers { header += "\(k): \(v)\r\n" }
            header += "Content-Length: \(body.count)\r\n\r\n"
            var out = Data(header.utf8)
            out.append(body)
            await send(out, to: connection)
            connection.cancel()
        }
    }

    private func send(_ data: Data, to connection: NWConnection) async {
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    private func statusText(_ code: Int) -> String {
        switch code {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 406: "Not Acceptable"
        case 409: "Conflict"
        case 415: "Unsupported Media Type"
        case 421: "Misdirected Request"
        default: "Error"
        }
    }

    // MARK: - Static parsing helpers (tested in HTTPParserTests)

    static func parseRequest(_ data: Data) -> HTTPRequest? {
        let sep = Data("\r\n\r\n".utf8)
        guard let sepRange = data.range(of: sep) else { return nil }
        guard let headerStr = String(data: data[..<sepRange.lowerBound], encoding: .utf8) else { return nil }

        var lines = headerStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        lines.removeFirst()

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        let method = parts[0], path = parts[1]

        var headers: [String: String] = [:]
        for line in lines {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { headers[name] = value }
        }

        let bodyStart = sepRange.upperBound
        let body = bodyStart < data.endIndex ? Data(data[bodyStart...]) : nil

        return HTTPRequest(method: method, headers: headers, body: body?.isEmpty == true ? nil : body, path: path)
    }

    static func parseContentLength(from headerData: Data) -> Int? {
        guard let str = String(data: headerData, encoding: .utf8) else { return nil }
        for line in str.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                return Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}
