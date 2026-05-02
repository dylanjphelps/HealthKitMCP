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

    func testQueryScheduledWorkoutsToolName() {
        XCTAssertEqual(QueryScheduledWorkoutsTool.toolName, "query_scheduled_workouts")
    }

    func testDeleteScheduledWorkoutToolName() {
        XCTAssertEqual(DeleteScheduledWorkoutTool.toolName, "delete_scheduled_workout")
    }

    func testDeleteScheduledWorkoutParseIndex() {
        XCTAssertEqual(DeleteScheduledWorkoutTool.parseIndex(from: ["index": .int(2)]), 2)
    }

    func testDeleteScheduledWorkoutParseIndexMissing() {
        XCTAssertNil(DeleteScheduledWorkoutTool.parseIndex(from: [:]))
    }
}
