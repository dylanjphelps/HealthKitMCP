import HealthKit
import Foundation

actor HealthKitManager {
    private let store = HKHealthStore()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType(),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningGroundContactTime),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningStrideLength),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    var isAuthorized: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Workouts

    func queryWorkouts(days: Int) async throws -> [WorkoutResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let iso = ISO8601DateFormatter()
                let hrUnit = HKUnit(from: "count/min")
                let results = (samples as? [HKWorkout] ?? [])
                    .filter { $0.workoutActivityType == .running }
                    .map { w -> WorkoutResult in
                        let distMiles = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                            .sumQuantity()?.doubleValue(for: .mile()) ?? 0
                        let pace = distMiles > 0 ? w.duration / distMiles : 0
                        let cal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        let hr = w.statistics(for: HKQuantityType(.heartRate))?
                            .averageQuantity()?.doubleValue(for: hrUnit)
                        let maxHR = w.statistics(for: HKQuantityType(.heartRate))?
                            .maximumQuantity()?.doubleValue(for: hrUnit)
                        let elevUp = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
                            .doubleValue(for: .foot())
                        let elevDown = (w.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity)?
                            .doubleValue(for: .foot())
                        let isIndoor = w.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
                        let avgPower = w.statistics(for: HKQuantityType(.runningPower))?
                            .averageQuantity()?.doubleValue(for: .watt())
                        let maxPower = w.statistics(for: HKQuantityType(.runningPower))?
                            .maximumQuantity()?.doubleValue(for: .watt())
                        let steps = w.statistics(for: HKQuantityType(.stepCount))?
                            .sumQuantity()?.doubleValue(for: .count())
                        let cadence = steps.map { $0 / w.duration * 60 }
                        let strideLen = w.statistics(for: HKQuantityType(.runningStrideLength))?
                            .averageQuantity()?.doubleValue(for: .foot())
                        let vertOsc = w.statistics(for: HKQuantityType(.runningVerticalOscillation))?
                            .averageQuantity()?.doubleValue(for: .inch())
                        let gct = w.statistics(for: HKQuantityType(.runningGroundContactTime))?
                            .averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        return WorkoutResult(
                            date: iso.string(from: w.startDate),
                            duration_minutes: w.duration / 60,
                            distance_miles: distMiles,
                            pace_sec_per_mile: pace,
                            avg_heart_rate_bpm: hr.flatMap { $0 > 0 ? Optional($0) : nil },
                            max_heart_rate_bpm: maxHR.flatMap { $0 > 0 ? Optional($0) : nil },
                            active_calories: cal,
                            elevation_ascended_feet: elevUp,
                            elevation_descended_feet: elevDown,
                            is_indoor: isIndoor,
                            avg_running_power_watts: avgPower,
                            max_running_power_watts: maxPower,
                            avg_cadence_spm: cadence,
                            avg_stride_length_feet: strideLen,
                            avg_vertical_oscillation_inches: vertOsc,
                            avg_ground_contact_time_ms: gct,
                            weather_temperature_fahrenheit: (w.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity)?
                                .doubleValue(for: .degreeFahrenheit()),
                            weather_humidity_percent: (w.metadata?[HKMetadataKeyWeatherHumidity] as? HKQuantity)
                                .map { $0.doubleValue(for: .percent()) * 100 }
                        )
                    }
                continuation.resume(returning: results)
            }
            store.execute(q)
        }
    }

    // MARK: - Activity Summary

    func queryActivitySummary(days: Int) async throws -> [ActivitySummaryResult] {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end)!

        async let summaries = fetchActivitySummaries(from: start, to: end)
        async let steps = fetchDailySteps(from: start, to: end)

        let (summaryList, stepsMap) = try await (summaries, steps)

        return summaryList.map { s in
            ActivitySummaryResult(
                date: s.date,
                steps: Int(stepsMap[s.date] ?? 0),
                active_calories: s.activeCalories,
                exercise_minutes: s.exerciseMinutes
            )
        }
    }

    private struct ActivitySummaryRaw {
        let date: String
        let activeCalories: Double
        let exerciseMinutes: Double
    }

    private func fetchActivitySummaries(from start: Date, to end: Date) async throws -> [ActivitySummaryRaw] {
        let calendar = Calendar.current
        let startC = calendar.dateComponents([.year, .month, .day], from: start)
        let endC = calendar.dateComponents([.year, .month, .day], from: end)
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startC, end: endC)
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error { continuation.resume(throwing: error); return }
                let calendar = Calendar.current
                let results = (summaries ?? []).map { s -> ActivitySummaryRaw in
                    let dc = s.dateComponents(for: calendar)
                    let date = String(format: "%04d-%02d-%02d", dc.year ?? 0, dc.month ?? 0, dc.day ?? 0)
                    return ActivitySummaryRaw(
                        date: date,
                        activeCalories: s.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                        exerciseMinutes: s.appleExerciseTime.doubleValue(for: .minute())
                    )
                }
                continuation.resume(returning: results)
            }
            store.execute(q)
        }
    }

    private func fetchDailySteps(from start: Date, to end: Date) async throws -> [String: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.stepCount),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                var dict: [String: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        dict[formatter.string(from: stats.startDate)] = sum.doubleValue(for: .count())
                    }
                }
                continuation.resume(returning: dict)
            }
            store.execute(q)
        }
    }

    // MARK: - Resting Heart Rate

    func queryRestingHeartRate(days: Int) async throws -> [RestingHRResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let unit = HKUnit(from: "count/min")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.restingHeartRate),
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMin, .discreteMax],
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                var data: [RestingHRResult] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    data.append(RestingHRResult(
                        date: formatter.string(from: stats.startDate),
                        avg_bpm: avg.doubleValue(for: unit),
                        min_bpm: stats.minimumQuantity()?.doubleValue(for: unit),
                        max_bpm: stats.maximumQuantity()?.doubleValue(for: unit)
                    ))
                }
                continuation.resume(returning: data)
            }
            store.execute(q)
        }
    }

    // MARK: - VO2 Max

    func queryVO2Max() async throws -> VO2MaxResult? {
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        let unit = HKUnit(from: "ml/kg*min")
        let iso = ISO8601DateFormatter()
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKQuantityType(.vo2Max),
                predicate: nil,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: VO2MaxResult(
                    date: iso.string(from: sample.startDate),
                    vo2max_ml_kg_min: sample.quantity.doubleValue(for: unit)
                ))
            }
            store.execute(q)
        }
    }
}
