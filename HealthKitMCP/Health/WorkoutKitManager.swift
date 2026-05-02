// HealthKitMCP/Health/WorkoutKitManager.swift
import WorkoutKit
import Foundation

// MARK: - Step and Block specs

struct StepSpec {
    let goalType: String      // "time" | "distance"
    let goalValue: Double     // minutes if time, miles if distance
    let targetPaceSecPerMile: Double?
    let targetHeartRateBpm: Double?

    var workoutGoal: WorkoutGoal {
        goalType == "distance"
            ? .distance(goalValue * 1609.344, .meters)
            : .time(goalValue * 60, .seconds)
    }
}

struct BlockSpec {
    let repeatCount: Int
    let work: StepSpec
    let rest: StepSpec?
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

        let warmupStep = warmup.map { WorkoutStep(goal: $0.workoutGoal, alert: alert(for: $0)) }
        let cooldownStep = cooldown.map { WorkoutStep(goal: $0.workoutGoal, alert: alert(for: $0)) }

        let intervalBlocks: [IntervalBlock] = blocks.map { block in
            let workStep = IntervalStep(.work, goal: block.work.workoutGoal, alert: alert(for: block.work))
            var steps: [IntervalStep] = [workStep]
            if let rest = block.rest {
                steps.append(IntervalStep(.recovery, goal: rest.workoutGoal, alert: alert(for: rest)))
            }
            return IntervalBlock(steps: steps, iterations: block.repeatCount)
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
        if await scheduler.authorizationState == .notDetermined {
            _ = await scheduler.requestAuthorization()
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.calendar = Calendar.current
        let plan = WorkoutPlan(.custom(workout))
        await scheduler.schedule(plan, at: components)
    }
}

enum WorkoutError: Error, LocalizedError {
    case invalidType(String)
    var errorDescription: String? {
        switch self { case .invalidType(let m): return m }
    }
}
