import XCTest
import MCP
import WorkoutKit
@testable import HealthKitMCP

final class QueryToolParsingTests: XCTestCase {

    func testParseDaysUsesIntegerValueOrDefault() {
        let cases: [(name: String, args: [String: Value], defaultDays: Int, expected: Int)] = [
            ("missing uses default", [:], 7, 7),
            ("custom integer overrides default", ["days": .int(14)], 7, 14),
            ("body mass default is supported", [:], 30, 30),
            ("non-integer value falls back to default", ["days": .double(14.5)], 7, 7),
            ("string value falls back to default", ["days": .string("14")], 7, 7)
        ]

        for testCase in cases {
            XCTAssertEqual(
                parseDays(from: testCase.args, default: testCase.defaultDays),
                testCase.expected,
                testCase.name
            )
        }
    }

    func testRoundedValueUsesRequestedPrecision() {
        let cases: [(name: String, value: Double, places: Int, expected: Double)] = [
            ("two decimal places", 3.14159, 2, 3.14),
            ("zero decimal places", 3.14159, 0, 3.0),
            ("zero stays zero", 0.0, 2, 0.0),
            ("negative values round correctly", -1.23456, 3, -1.235),
            ("large values round correctly", 1_234_567.89, 1, 1_234_567.9)
        ]

        for testCase in cases {
            XCTAssertEqual(
                roundedValue(testCase.value, places: testCase.places),
                testCase.expected,
                accuracy: 0.000_001,
                testCase.name
            )
        }
    }

    func testParseLimitAppliesDefaultAndBounds() {
        let cases: [(name: String, args: [String: Value], defaultLimit: Int, maxLimit: Int, expected: Int)] = [
            ("missing uses default", [:], 50, 500, 50),
            ("custom limit within bounds", ["limit": .int(125)], 50, 500, 125),
            ("limit above max is clamped", ["limit": .int(700)], 50, 500, 500),
            ("zero uses default", ["limit": .int(0)], 50, 500, 50),
            ("negative uses default", ["limit": .int(-10)], 50, 500, 50)
        ]

        for testCase in cases {
            XCTAssertEqual(
                parseLimit(from: testCase.args, default: testCase.defaultLimit, max: testCase.maxLimit),
                testCase.expected,
                testCase.name
            )
        }
    }

    func testParseBooleanOptionDefaultsToFalseWhenMissing() {
        let keys = ["include_splits", "include_steps", "include_intervals", "include_description"]

        for key in keys {
            XCTAssertFalse(parseBooleanOption(key, from: [:]), key)
        }
    }

    func testParseBooleanOptionReturnsExplicitValue() {
        let cases: [(name: String, key: String, args: [String: Value], expected: Bool)] = [
            ("include_splits true", "include_splits", ["include_splits": .bool(true)], true),
            ("include_splits false", "include_splits", ["include_splits": .bool(false)], false),
            ("include_steps true", "include_steps", ["include_steps": .bool(true)], true),
            ("include_steps false", "include_steps", ["include_steps": .bool(false)], false),
            ("include_intervals true", "include_intervals", ["include_intervals": .bool(true)], true),
            ("include_intervals false", "include_intervals", ["include_intervals": .bool(false)], false),
            ("include_description true", "include_description", ["include_description": .bool(true)], true),
            ("include_description false", "include_description", ["include_description": .bool(false)], false)
        ]

        for testCase in cases {
            XCTAssertEqual(
                parseBooleanOption(testCase.key, from: testCase.args),
                testCase.expected,
                testCase.name
            )
        }
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

    func testDeleteScheduledWorkoutParseIndexAcceptsOnlyIntegers() {
        let cases: [(name: String, args: [String: Value], expected: Int?)] = [
            ("integer index is returned", ["index": .int(2)], 2),
            ("missing index returns nil", [:], nil),
            ("double index returns nil", ["index": .double(2.0)], nil),
            ("string index returns nil", ["index": .string("2")], nil)
        ]

        for testCase in cases {
            XCTAssertEqual(DeleteScheduledWorkoutTool.parseIndex(from: testCase.args), testCase.expected, testCase.name)
        }
    }

    func testParseStandaloneWorkStepDefaultsAndTargets() {
        let value = Value.object([
            "display_name": .string("Steady"),
            "goal_type": .string("time"),
            "goal_value": .int(20),
            "target_pace_seconds_per_mile": .int(480),
            "target_heart_rate_bpm": .int(150)
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.repeatCount, 1)
        XCTAssertEqual(block?.steps.count, 1)
        XCTAssertEqual(block?.steps.first?.purpose, .work)
        XCTAssertEqual(block?.steps.first?.spec.displayName, "Steady")
        XCTAssertEqual(block?.steps.first?.spec.goalValue, 20.0)
        XCTAssertEqual(block?.steps.first?.spec.targetPaceSecPerMile, 480.0)
        XCTAssertEqual(block?.steps.first?.spec.targetHeartRateBpm, 150.0)
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

    func testParseStandaloneStepDefaultsGoalTypeAndValue() {
        let value = Value.object([:])

        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)

        XCTAssertEqual(block?.repeatCount, 1)
        XCTAssertEqual(block?.steps.first?.purpose, .work)
        XCTAssertEqual(block?.steps.first?.spec.goalType, "time")
        XCTAssertEqual(block?.steps.first?.spec.goalValue, 0.0)
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

    func testParseIntervalBlockConvertsDoubleRepeatCountAndSkipsInvalidSteps() {
        let value = Value.object([
            "repeat_count": .double(3.9),
            "steps": .array([
                .object(["purpose": .string("work"), "goal_type": .string("distance"), "goal_value": .double(0.5)]),
                .string("skip me"),
                .object(["purpose": .string("recovery"), "goal_type": .string("time"), "goal_value": .int(2)])
            ])
        ])

        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)

        XCTAssertEqual(block?.repeatCount, 3)
        XCTAssertEqual(block?.steps.count, 2)
        XCTAssertEqual(block?.steps[0].spec.goalType, "distance")
        XCTAssertEqual(block?.steps[1].purpose, .recovery)
    }

    func testParseIntervalBlockEmptyStepsReturnsNil() {
        let value = Value.object([
            "steps": .array([])
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNil(block)
    }

    func testParseIntervalBlockDefaultRepeatCount() {
        let value = Value.object([
            "steps": .array([
                .object(["purpose": .string("work"), "goal_type": .string("time"), "goal_value": .int(5)])
            ])
        ])
        let block = ScheduleWorkoutTool.parseBlockSpec(from: value)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.repeatCount, 1)
    }

    func testParseIntervalBlockInvalidShapeReturnsNil() {
        XCTAssertNil(ScheduleWorkoutTool.parseBlockSpec(from: .string("invalid")))
        XCTAssertNil(ScheduleWorkoutTool.parseBlockSpec(from: .object(["steps": .string("invalid")])))
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
