// HealthKitMCP/Health/WorkoutKitManager.swift
import WorkoutKit
import Foundation

// MARK: - Step and Block specs

struct StepSpec {
    let goalType: String      // "time" | "distance"
    let goalValue: Double     // minutes if time, miles if distance
    let targetPaceSecPerMile: Double?
    let targetHeartRateBpm: Double?
    let displayName: String?

    var workoutGoal: WorkoutGoal {
        switch goalType {
        case "distance": return .distance(goalValue, .miles)
        case "open":     return .open
        default:         return .time(goalValue * 60, .seconds)
        }
    }
}

struct BlockSpec {
    let repeatCount: Int
    let work: StepSpec
    let rest: StepSpec?
    let restAfter: StepSpec?  // single recovery block emitted after all iterations
}

// MARK: - Manager

actor WorkoutKitManager {

    /// Validates the workout structure and returns a human-readable description.
    func buildCustom(
        title: String,
        warmup: StepSpec?,
        blocks: [BlockSpec],
        cooldown: StepSpec?
    ) throws -> (CustomWorkout, String) {
        guard !blocks.isEmpty else {
            throw WorkoutError.invalidType("blocks array must not be empty")
        }

        let warmupStep = warmup.map { makeStep($0) }
        let cooldownStep = cooldown.map { makeStep($0) }

        let intervalBlocks: [IntervalBlock] = blocks.flatMap { block -> [IntervalBlock] in
            let workStep = IntervalStep(.work, goal: block.work.workoutGoal, alert: alert(for: block.work))
            var steps: [IntervalStep] = [workStep]
            if let rest = block.rest {
                steps.append(IntervalStep(.recovery, goal: rest.workoutGoal, alert: alert(for: rest)))
            }
            let mainBlock = IntervalBlock(steps: steps, iterations: block.repeatCount)
            guard let restAfter = block.restAfter else { return [mainBlock] }
            let restBlock = IntervalBlock(
                steps: [IntervalStep(.recovery, goal: restAfter.workoutGoal, alert: alert(for: restAfter))],
                iterations: 1
            )
            return [mainBlock, restBlock]
        }

        let workout = CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: title,
            warmup: warmupStep,
            blocks: intervalBlocks,
            cooldown: cooldownStep
        )

        let description = describeWorkout(title: title, warmup: warmup, blocks: blocks, cooldown: cooldown)
        return (workout, description)
    }

    // MARK: - Step helpers

    private func makeStep(_ spec: StepSpec) -> WorkoutStep {
        WorkoutStep(goal: spec.workoutGoal, alert: alert(for: spec), displayName: spec.displayName)
    }

    // MARK: - Alert helpers

    private func alert(for step: StepSpec) -> (any WorkoutAlert)? {
        if let bpm = step.targetHeartRateBpm {
            return heartRateAlert(bpm: bpm)
        } else if let pace = step.targetPaceSecPerMile {
            return paceAlert(paceSecPerMile: pace, toleranceSec: 10)
        }
        return nil
    }

    private func paceAlert(paceSecPerMile: Double, toleranceSec: Double) -> SpeedRangeAlert {
        let slowPace = paceSecPerMile + toleranceSec
        let fastPace = max(paceSecPerMile - toleranceSec, 1.0)
        return SpeedRangeAlert(
            target: Measurement(value: 1609.344 / slowPace, unit: .metersPerSecond)
                ... Measurement(value: 1609.344 / fastPace, unit: .metersPerSecond),
            metric: .current
        )
    }

    private func heartRateAlert(bpm: Double) -> HeartRateRangeAlert {
        return .heartRate((bpm - 5)...(bpm + 5))
    }

    // MARK: - Description

    func describeWorkout(
        title: String,
        warmup: StepSpec?,
        blocks: [BlockSpec],
        cooldown: StepSpec?
    ) -> String {
        var parts: [String] = []

        if let w = warmup { parts.append(stepLabel(w) + " warmup") }

        for block in blocks {
            let workDesc = stepLabel(block.work)
            if let rest = block.rest {
                let restDesc = stepLabel(rest)
                parts.append(block.repeatCount > 1
                    ? "\(block.repeatCount)×(\(workDesc) + \(restDesc) recovery)"
                    : "(\(workDesc) + \(restDesc) recovery)")
            } else {
                parts.append(block.repeatCount > 1
                    ? "\(block.repeatCount)×\(workDesc)"
                    : workDesc)
            }
        }

        if let c = cooldown { parts.append(stepLabel(c) + " cooldown") }

        return parts.joined(separator: " → ")
    }

    private func stepLabel(_ step: StepSpec) -> String {
        step.goalType == "distance" ? "\(step.goalValue)mi" : "\(step.goalValue)min"
    }

    // MARK: - Scheduling

    func schedule(_ workout: CustomWorkout, for date: Date) async throws {
        let scheduler = WorkoutScheduler.shared
        let state = await scheduler.authorizationState
        if state == .notDetermined {
            let granted = await scheduler.requestAuthorization()
            guard granted == .authorized else {
                throw WorkoutError.authorizationDenied
            }
        } else if state == .denied {
            throw WorkoutError.authorizationDenied
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.calendar = Calendar.current
        let plan = WorkoutPlan(.custom(workout))
        await scheduler.schedule(plan, at: components)
    }

    func queryScheduled() async throws -> [ScheduledWorkoutResult] {
        let scheduler = WorkoutScheduler.shared
        let state = await scheduler.authorizationState
        if state == .notDetermined {
            let granted = await scheduler.requestAuthorization()
            guard granted == .authorized else { throw WorkoutError.authorizationDenied }
        } else if state == .denied {
            throw WorkoutError.authorizationDenied
        }
        let plans = await scheduler.scheduledWorkouts
        return plans.enumerated().map { index, scheduled in
            let (title, type) = workoutInfo(from: scheduled.plan)
            let date = dateString(from: scheduled.date)
            return ScheduledWorkoutResult(index: index, date: date, title: title, type: type)
        }
    }

    private func workoutInfo(from plan: WorkoutPlan) -> (title: String, type: String) {
        if let custom = plan.workout as? CustomWorkout {
            return (custom.displayName ?? "(unnamed)", "custom")
        }
        return ("(unnamed)", "unknown")
    }

    private func dateString(from components: DateComponents) -> String {
        guard let year = components.year, let month = components.month, let day = components.day else {
            return "(unknown date)"
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum WorkoutError: Error, LocalizedError {
    case invalidType(String)
    case invalidIndex(String)
    case authorizationDenied
    var errorDescription: String? {
        switch self {
        case .invalidType(let m): return m
        case .invalidIndex(let m): return m
        case .authorizationDenied:
            return "WorkoutKit access is denied. Re-enable it in Settings > Privacy & Security > Motion & Fitness, then try again."
        }
    }
}
