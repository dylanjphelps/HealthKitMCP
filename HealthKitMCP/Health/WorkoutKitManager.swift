// HealthKitMCP/Health/WorkoutKitManager.swift
import WorkoutKit
import Foundation

// MARK: - Step and Block specs (top-level, outside the actor)

@available(macOS 15.0, *)
struct StepSpec {
    let goalType: String      // "time" | "distance"
    let goalValue: Double     // minutes if time, km if distance
    let targetPaceSecPerKm: Double?
    let targetHeartRateBpm: Double?

    var workoutGoal: WorkoutGoal {
        goalType == "distance"
            ? .distance(goalValue * 1000, .meters)
            : .time(goalValue * 60, .seconds)
    }
}

@available(macOS 15.0, *)
struct BlockSpec {
    let repeatCount: Int
    let work: StepSpec
    let rest: StepSpec?
}

// MARK: - Manager

@available(macOS 15.0, *)
actor WorkoutKitManager {

    /// Builds a CustomWorkout from the blocks-based schema and returns a human-readable description.
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

        let description = describeCustomWorkout(title: title, warmup: warmup, blocks: blocks, cooldown: cooldown)
        return (workout, description)
    }

    /// Wraps the CustomWorkout in a WorkoutPlan and schedules it for today via WorkoutScheduler.
    func schedule(_ workout: CustomWorkout) async throws {
        let plan = WorkoutPlan(.custom(workout))
        let date = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        await WorkoutScheduler.shared.schedule(plan, at: date)
    }

    // MARK: - Alert helpers

    /// Returns the appropriate WorkoutAlert for a step, preferring HR over pace.
    private func alert(for step: StepSpec) -> (any WorkoutAlert)? {
        if let bpm = step.targetHeartRateBpm {
            return heartRateAlert(bpm: bpm)
        } else if let pace = step.targetPaceSecPerKm {
            return paceAlert(paceSecPerKm: pace, toleranceSec: 10)
        }
        return nil
    }

    /// Converts a target pace (seconds/km) ± tolerance into a SpeedRangeAlert (m/s).
    /// WorkoutKit does not expose a pace alert; speed = 1000 / paceSecPerKm.
    private func paceAlert(paceSecPerKm: Double, toleranceSec: Double) -> SpeedRangeAlert {
        // Faster pace (fewer seconds) → higher speed; clamp to avoid div/0
        let slowPace = paceSecPerKm + toleranceSec
        let fastPace = max(paceSecPerKm - toleranceSec, 1.0)
        let slowSpeedMps = 1000.0 / slowPace
        let fastSpeedMps = 1000.0 / fastPace
        return SpeedRangeAlert(
            target: Measurement(value: slowSpeedMps, unit: .metersPerSecond)
                ... Measurement(value: fastSpeedMps, unit: .metersPerSecond),
            metric: .current
        )
    }

    /// Creates a HeartRateRangeAlert centered on bpm with ±5 BPM tolerance.
    /// Uses the static convenience initializer: .heartRate(_ range: ClosedRange<Double>, unit: UnitFrequency)
    private func heartRateAlert(bpm: Double) -> HeartRateRangeAlert {
        return .heartRate((bpm - 5)...(bpm + 5))
    }

    // MARK: - Description

    private func describeCustomWorkout(
        title: String,
        warmup: StepSpec?,
        blocks: [BlockSpec],
        cooldown: StepSpec?
    ) -> String {
        var parts: [String] = []

        if let w = warmup {
            parts.append(describeStep(w, label: "warmup"))
        }

        for block in blocks {
            let workDesc = describeStepShort(block.work)
            if let rest = block.rest {
                let restDesc = describeStepShort(rest)
                let blockDesc = block.repeatCount > 1
                    ? "\(block.repeatCount)×(\(workDesc) + \(restDesc) recovery)"
                    : "(\(workDesc) + \(restDesc) recovery)"
                parts.append(blockDesc)
            } else {
                let blockDesc = block.repeatCount > 1
                    ? "\(block.repeatCount)×\(workDesc)"
                    : workDesc
                parts.append(blockDesc)
            }
        }

        if let c = cooldown {
            parts.append(describeStep(c, label: "cooldown"))
        }

        return parts.joined(separator: " → ")
    }

    private func describeStep(_ step: StepSpec, label: String) -> String {
        let goalDesc = step.goalType == "distance"
            ? "\(step.goalValue)km"
            : "\(step.goalValue)min"
        return "\(goalDesc) \(label)"
    }

    private func describeStepShort(_ step: StepSpec) -> String {
        return step.goalType == "distance"
            ? "\(step.goalValue)km"
            : "\(step.goalValue)min"
    }


}

enum WorkoutError: Error, LocalizedError {
    case invalidType(String)

    var errorDescription: String? {
        switch self {
        case .invalidType(let message):
            return message
        }
    }
}
