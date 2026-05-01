// HealthKitMCP/MCP/Tools/ListScheduledWorkoutsTool.swift
import Foundation
import MCP
import WorkoutKit

@available(macOS 15.0, *)
enum ListScheduledWorkoutsTool {
    static func handle() async throws -> String {
        let manager = WorkoutKitManager()
        let authState = await manager.authorizationState()
        let plans = await manager.listScheduled()

        struct ScheduledPlanRecord: Encodable {
            let title: String
            let date: String
        }

        struct Result: Encodable {
            let authorization_state: String
            let scheduled_count: Int
            let workouts: [ScheduledPlanRecord]
        }

        let isoDay: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withFullDate]
            return f
        }()

        let records = plans.compactMap { scheduled -> ScheduledPlanRecord? in
            guard case .custom(let workout) = scheduled.plan.workout else { return nil }
            let dateStr: String
            if let date = Calendar.current.date(from: scheduled.date) {
                dateStr = isoDay.string(from: date)
            } else {
                dateStr = "\(scheduled.date)"
            }
            return ScheduledPlanRecord(title: workout.displayName ?? "(untitled)", date: dateStr)
        }

        return try encodeToJSON(Result(
            authorization_state: authState,
            scheduled_count: plans.count,
            workouts: records
        ))
    }
}
