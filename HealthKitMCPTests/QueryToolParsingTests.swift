import XCTest
import MCP
@testable import HealthKitMCP

final class QueryToolParsingTests: XCTestCase {

    func testQueryWorkoutsDefaultDays() {
        let days = QueryWorkoutsTool.parseDays(from: [:])
        XCTAssertEqual(days, 7)
    }

    func testQueryWorkoutsCustomDays() {
        let days = QueryWorkoutsTool.parseDays(from: ["days": .int(14)])
        XCTAssertEqual(days, 14)
    }

    func testQueryActivitySummaryDefaultDays() {
        let days = QueryActivitySummaryTool.parseDays(from: [:])
        XCTAssertEqual(days, 7)
    }

    func testQueryRestingHeartRateDefaultDays() {
        let days = QueryRestingHeartRateTool.parseDays(from: [:])
        XCTAssertEqual(days, 7)
    }

    func testVO2MaxToolNameIsCorrect() {
        XCTAssertEqual(QueryVO2MaxTool.toolName, "query_vo2max")
    }
}
