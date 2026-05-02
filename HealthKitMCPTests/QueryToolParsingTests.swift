import XCTest
import MCP
import WorkoutKit
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

    func testParseStandaloneWorkStepDefaultPurpose() {
        let value = Value.object([
            "goal_type": .string("time"),
            "goal_value": .int(20)
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.repeatCount, 1)
        XCTAssertEqual(block?.steps.count, 1)
        XCTAssertEqual(block?.steps.first?.purpose, .work)
        XCTAssertEqual(block?.steps.first?.spec.goalValue, 20.0)
    }

    func testParseStandaloneRecoveryStep() {
        let value = Value.object([
            "purpose": .string("recovery"),
            "goal_type": .string("time"),
            "goal_value": .int(3)
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.steps.first?.purpose, .recovery)
    }

    func testParseIntervalBlockTwoSteps() {
        let value = Value.object([
            "repeat_count": .int(4),
            "steps": .array([
                .object(["purpose": .string("work"), "goal_type": .string("time"), "goal_value": .int(1)]),
                .object(["purpose": .string("recovery"), "goal_type": .string("time"), "goal_value": .int(1)])
            ])
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.repeatCount, 4)
        XCTAssertEqual(block?.steps.count, 2)
        XCTAssertEqual(block?.steps[0].purpose, .work)
        XCTAssertEqual(block?.steps[1].purpose, .recovery)
    }

    func testParseIntervalBlockThreeSteps() {
        let value = Value.object([
            "repeat_count": .int(3),
            "steps": .array([
                .object(["purpose": .string("work"), "goal_type": .string("time"), "goal_value": .int(1)]),
                .object(["purpose": .string("work"), "goal_type": .string("time"), "goal_value": .double(0.5)]),
                .object(["purpose": .string("recovery"), "goal_type": .string("time"), "goal_value": .int(1)])
            ])
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.steps.count, 3)
        XCTAssertEqual(block?.steps[0].purpose, .work)
        XCTAssertEqual(block?.steps[1].purpose, .work)
        XCTAssertEqual(block?.steps[2].purpose, .recovery)
    }
}
