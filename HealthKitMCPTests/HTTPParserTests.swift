import XCTest
@testable import HealthKitMCP

final class HTTPParserTests: XCTestCase {

    func testParseGETRequest() {
        let raw = "GET /mcp HTTP/1.1\r\nHost: 192.168.1.5:8080\r\nAccept: text/event-stream\r\n\r\n"
        let data = Data(raw.utf8)
        let req = HTTPServer.parseRequest(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/mcp")
        XCTAssertNil(req?.body)
    }

    func testParsePOSTWithBody() {
        let body = #"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#
        let raw = "POST /mcp HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let data = Data(raw.utf8)
        let req = HTTPServer.parseRequest(data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.method, "POST")
        XCTAssertEqual(req?.body, Data(body.utf8))
    }

    func testParseHeadersCaseInsensitive() {
        let raw = "GET /mcp HTTP/1.1\r\nhost: iphone.local:8080\r\n\r\n"
        let req = HTTPServer.parseRequest(Data(raw.utf8))
        XCTAssertEqual(req?.header("Host"), "iphone.local:8080")
    }

    func testContentLengthExtraction() {
        let headerData = Data("POST /mcp HTTP/1.1\r\nContent-Length: 42\r\nHost: x".utf8)
        XCTAssertEqual(HTTPServer.parseContentLength(from: headerData), 42)
    }

    func testMissingContentLengthReturnsNil() {
        let headerData = Data("GET /mcp HTTP/1.1\r\nHost: x".utf8)
        XCTAssertNil(HTTPServer.parseContentLength(from: headerData))
    }

    func testMalformedRequestLineReturnsNil() {
        let data = Data("BADREQUEST\r\n\r\n".utf8)
        XCTAssertNil(HTTPServer.parseRequest(data))
    }
}
