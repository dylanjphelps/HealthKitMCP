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

    func testParseIntegerValid() {
        XCTAssertEqual(parseInteger(named: "count", from: ["count": .int(42)]), 42)
    }

    func testParseIntegerMissing() {
        XCTAssertNil(parseInteger(named: "count", from: [:]))
    }

    func testParseIntegerWrongType() {
        XCTAssertNil(parseInteger(named: "count", from: ["count": .string("hello")]))
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

    func testQueryElevationToolName() {
        XCTAssertEqual(QueryElevationTool.toolName, "query_elevation")
    }

    func testQueryHeartRateZonesToolName() {
        XCTAssertEqual(QueryHeartRateZonesTool.toolName, "query_heart_rate_zones")
    }

    func testSmoothAltitudesFlat() {
        let altitudes = [100.0, 100.0, 100.0, 100.0, 100.0]
        XCTAssertEqual(smoothAltitudes(altitudes), altitudes)
    }

    func testSmoothAltitudesSmooths() {
        let altitudes = [100.0, 100.0, 102.0, 100.0, 100.0]
        let result = smoothAltitudes(altitudes)

        XCTAssertEqual(result.count, altitudes.count)
        XCTAssertEqual(result[0], 100.666_667, accuracy: 0.000_001)
        XCTAssertEqual(result[1], 100.5, accuracy: 0.000_001)
        XCTAssertEqual(result[2], 100.4, accuracy: 0.000_001)
        XCTAssertEqual(result[3], 100.5, accuracy: 0.000_001)
        XCTAssertEqual(result[4], 100.666_667, accuracy: 0.000_001)
        XCTAssertLessThan(result[2], altitudes[2])
    }

    func testSmoothAltitudesPreservesCount() {
        let altitudes = [99.5, 100.0, 100.5, 101.0, 101.5, 102.0]
        XCTAssertEqual(smoothAltitudes(altitudes).count, altitudes.count)
    }

    func testSmoothAltitudesEdges() {
        let twoPoint = smoothAltitudes([100.0, 102.0])
        XCTAssertEqual(twoPoint[0], 101.0, accuracy: 0.000_001)
        XCTAssertEqual(twoPoint[1], 101.0, accuracy: 0.000_001)

        let threePoint = smoothAltitudes([100.0, 102.0, 104.0])
        XCTAssertEqual(threePoint[0], 102.0, accuracy: 0.000_001)
        XCTAssertEqual(threePoint[1], 102.0, accuracy: 0.000_001)
        XCTAssertEqual(threePoint[2], 102.0, accuracy: 0.000_001)
    }

    func testSmoothAltitudesEmptyAndSingle() {
        XCTAssertEqual(smoothAltitudes([]), [Double]())
        XCTAssertEqual(smoothAltitudes([123.4]), [123.4])
    }

    func testComputeRouteElevationBasicAscent() {
        let altitudes = [100.0, 100.0, 100.0, 105.0, 110.0, 110.0, 105.0, 105.0, 105.0]
        let result = computeRouteElevation(altitudes: altitudes)
        let metersToFeet = 3.28084
        XCTAssertEqual(result.ascentFeet, 7.0 * metersToFeet, accuracy: 0.01)
        XCTAssertEqual(result.descentFeet, 2.0 * metersToFeet, accuracy: 0.01)
    }

    func testComputeRouteElevationFiltersNoise() {
        let altitudes = [100.0, 100.05, 99.97, 100.02, 100.0]
        let result = computeRouteElevation(altitudes: altitudes)
        XCTAssertEqual(result.ascentFeet, 0.0)
        XCTAssertEqual(result.descentFeet, 0.0)
    }

    func testComputeRouteElevationCapturesGradualChanges() {
        let altitudes = [
            100.0, 100.0, 100.3, 100.6, 100.9, 101.2, 101.5, 101.8, 102.1, 102.4,
            102.4, 102.1, 101.8, 101.5, 101.2, 100.9, 100.6, 100.3, 100.0, 100.0
        ]
        let result = computeRouteElevation(altitudes: altitudes)
        XCTAssertGreaterThan(result.ascentFeet, 5.0)
        XCTAssertLessThan(result.ascentFeet, 8.0)
        XCTAssertGreaterThan(result.descentFeet, 5.0)
        XCTAssertLessThan(result.descentFeet, 8.0)
    }

    func testComputeRouteElevationEmptyInput() {
        let result = computeRouteElevation(altitudes: [])
        XCTAssertEqual(result.ascentFeet, 0.0)
        XCTAssertEqual(result.descentFeet, 0.0)
    }

    func testComputeRouteElevationSinglePoint() {
        let result = computeRouteElevation(altitudes: [100.0])
        XCTAssertEqual(result.ascentFeet, 0.0)
        XCTAssertEqual(result.descentFeet, 0.0)
    }

    func testComputeRouteElevationRealisticGPSData() {
        let altitudes = (0..<100).map { 100.0 + (15.0 * Double($0) / 99.0) }
        let result = computeRouteElevation(altitudes: altitudes)

        XCTAssertGreaterThan(result.ascentFeet, 40.0)
        XCTAssertLessThan(result.ascentFeet, 55.0)
        XCTAssertEqual(result.descentFeet, 0.0, accuracy: 0.5)
    }

    func testParseZoneBoundariesDefault() {
        let result = QueryHeartRateZonesTool.parseZoneBoundaries(from: [:])
        XCTAssertNil(result)
    }

    func testParseZoneBoundariesCustom() {
        let args: [String: Value] = ["zone_boundaries": .array([.int(120), .int(150), .int(170)])]
        let result = QueryHeartRateZonesTool.parseZoneBoundaries(from: args)
        XCTAssertEqual(result, [120, 150, 170])
    }

    func testParseZoneBoundariesSortsValues() {
        let args: [String: Value] = ["zone_boundaries": .array([.int(170), .int(120), .int(150)])]
        let result = QueryHeartRateZonesTool.parseZoneBoundaries(from: args)
        XCTAssertEqual(result, [120, 150, 170])
    }

    func testParseZoneBoundariesEmptyArrayReturnsNil() {
        let args: [String: Value] = ["zone_boundaries": .array([])]
        let result = QueryHeartRateZonesTool.parseZoneBoundaries(from: args)
        XCTAssertNil(result)
    }

    func testComputeHeartRateZonesDistribution() {
        let readings: [(bpm: Double, durationSeconds: Double)] = [
            (bpm: 120, durationSeconds: 300),  // Zone 1: 5 min
            (bpm: 140, durationSeconds: 600),  // Zone 2: 10 min
            (bpm: 155, durationSeconds: 300),  // Zone 3: 5 min
            (bpm: 165, durationSeconds: 180),  // Zone 4: 3 min
            (bpm: 175, durationSeconds: 120),  // Zone 5: 2 min
        ]
        let zones = computeHeartRateZones(
            readings: readings,
            boundaries: QueryHeartRateZonesTool.defaultBoundaries,
            labels: QueryHeartRateZonesTool.defaultLabels
        )

        XCTAssertEqual(zones.count, 5)
        XCTAssertEqual(zones[0].zone, 1)
        XCTAssertEqual(zones[0].label, "Recovery")
        XCTAssertEqual(zones[0].duration_minutes, 5.0, accuracy: 0.01)
        XCTAssertEqual(zones[1].zone, 2)
        XCTAssertEqual(zones[1].label, "Easy Aerobic")
        XCTAssertEqual(zones[1].duration_minutes, 10.0, accuracy: 0.01)
        XCTAssertEqual(zones[4].zone, 5)
        XCTAssertEqual(zones[4].label, "VO2max+")
        XCTAssertEqual(zones[4].duration_minutes, 2.0, accuracy: 0.01)

        let totalPct = zones.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPct, 100.0, accuracy: 0.01)
    }

    func testComputeHeartRateZonesEmptyReadings() {
        let zones = computeHeartRateZones(
            readings: [],
            boundaries: [130, 149, 158, 168],
            labels: ["Z1", "Z2", "Z3", "Z4", "Z5"]
        )
        XCTAssertEqual(zones.count, 5)
        for zone in zones {
            XCTAssertEqual(zone.duration_minutes, 0.0)
            XCTAssertEqual(zone.percentage, 0.0)
        }
    }

    func testComputeHeartRateZonesCustomBoundaries() {
        let readings: [(bpm: Double, durationSeconds: Double)] = [
            (bpm: 110, durationSeconds: 600),
            (bpm: 160, durationSeconds: 600),
        ]
        let zones = computeHeartRateZones(
            readings: readings,
            boundaries: [150],
            labels: ["Below", "Above"]
        )
        XCTAssertEqual(zones.count, 2)
        XCTAssertEqual(zones[0].label, "Below")
        XCTAssertEqual(zones[0].range_bpm, "< 150")
        XCTAssertEqual(zones[0].percentage, 50.0, accuracy: 0.01)
        XCTAssertEqual(zones[1].label, "Above")
        XCTAssertEqual(zones[1].range_bpm, ">= 150")
        XCTAssertEqual(zones[1].percentage, 50.0, accuracy: 0.01)
    }

    func testComputeHeartRateZonesRangeLabels() {
        let zones = computeHeartRateZones(
            readings: [(bpm: 140, durationSeconds: 60)],
            boundaries: [130, 149, 158, 168],
            labels: ["Recovery", "Easy Aerobic", "Tempo", "Threshold", "VO2max+"]
        )
        XCTAssertEqual(zones[0].range_bpm, "< 130")
        XCTAssertEqual(zones[1].range_bpm, "130-148")
        XCTAssertEqual(zones[2].range_bpm, "149-157")
        XCTAssertEqual(zones[3].range_bpm, "158-167")
        XCTAssertEqual(zones[4].range_bpm, ">= 168")
    }

    func testPaginatedResponseLimitsResults() {
        let items = [1, 2, 3, 4, 5]
        let result = paginatedResponse(from: items, limit: 3)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.limit, 3)
        XCTAssertEqual(result.results, [1, 2, 3])
    }

    func testPaginatedResponseFullResults() {
        let items = [1, 2]
        let result = paginatedResponse(from: items, limit: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.limit, 10)
        XCTAssertEqual(result.results, [1, 2])
    }

    func testPaginatedResponseEmpty() {
        let items: [Int] = []
        let result = paginatedResponse(from: items, limit: 5)

        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.results, [])
    }
}
