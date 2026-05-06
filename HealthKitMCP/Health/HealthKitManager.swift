import HealthKit
import Foundation

actor HealthKitManager {
    private let store = HKHealthStore()

    // MARK: - Authorization

    // HKSampleType subset — used for statusForAuthorizationRequest (excludes activitySummaryType)
    private static let readSampleTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.bodyMass),
        HKQuantityType(.vo2Max),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.heartRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.runningStrideLength),
        HKCategoryType(.sleepAnalysis),
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var allTypes: Set<HKObjectType> = Set(Self.readSampleTypes)
        allTypes.insert(HKObjectType.activitySummaryType())
        try await store.requestAuthorization(toShare: [], read: allTypes)
    }

    static func needsAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let store = HKHealthStore()
        guard let status = try? await store.statusForAuthorizationRequest(toShare: [], read: readSampleTypes) else { return true }
        return status == .shouldRequest
    }

    var isAuthorized: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Workouts

    func queryWorkouts(days: Int) async throws -> [WorkoutResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end),
            HKQuery.predicateForWorkouts(with: .running)
        ])
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
                let results = (samples as? [HKWorkout] ?? []).map { w -> WorkoutResult in
                        let distMiles = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                            .sumQuantity()?.doubleValue(for: .mile()) ?? 0
                        let pace = distMiles > 0 ? w.duration / distMiles : 0
                        let cal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                        let hrStats = w.statistics(for: HKQuantityType(.heartRate))
                        let hr = hrStats?.averageQuantity()?.doubleValue(for: hrUnit)
                        let maxHR = hrStats?.maximumQuantity()?.doubleValue(for: hrUnit)
                        let elevUp = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
                            .doubleValue(for: .foot())
                        let elevDown = (w.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity)?
                            .doubleValue(for: .foot())
                        let isIndoor = w.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
                        let powerStats = w.statistics(for: HKQuantityType(.runningPower))
                        let avgPower = powerStats?.averageQuantity()?.doubleValue(for: .watt())
                        let maxPower = powerStats?.maximumQuantity()?.doubleValue(for: .watt())
                        let steps = w.statistics(for: HKQuantityType(.stepCount))?
                            .sumQuantity()?.doubleValue(for: .count())
                        let cadence = steps.map { $0 / w.duration * 60 }
                        let strideLen = w.statistics(for: HKQuantityType(.runningStrideLength))?
                            .averageQuantity()?.doubleValue(for: .foot())
                        let vertOsc = w.statistics(for: HKQuantityType(.runningVerticalOscillation))?
                            .averageQuantity()?.doubleValue(for: .inch())
                        let gct = w.statistics(for: HKQuantityType(.runningGroundContactTime))?
                            .averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        let splits = splitResults(from: w, totalDistance: distMiles)
                        let intervals = intervalResults(from: w)
                        return WorkoutResult(
                            date: iso.string(from: w.startDate),
                            duration_minutes: w.duration / 60,
                            distance_miles: distMiles,
                            pace_sec_per_mile: pace,
                            avg_heart_rate_bpm: hr.flatMap { $0 > 0 ? $0 : nil },
                            max_heart_rate_bpm: maxHR.flatMap { $0 > 0 ? $0 : nil },
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
                                .map { $0.doubleValue(for: .percent()) * 100 },
                            splits: splits,
                            intervals: intervals
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

    // MARK: - HRV

    func queryHRV(days: Int) async throws -> [HRVResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let unit = HKUnit(from: "ms")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.heartRateVariabilitySDNN),
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMin, .discreteMax],
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                var data: [HRVResult] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    data.append(HRVResult(
                        date: formatter.string(from: stats.startDate),
                        avg_ms: avg.doubleValue(for: unit),
                        min_ms: stats.minimumQuantity()?.doubleValue(for: unit),
                        max_ms: stats.maximumQuantity()?.doubleValue(for: unit)
                    ))
                }
                continuation.resume(returning: data)
            }
            store.execute(q)
        }
    }

    // MARK: - Body Mass

    func queryBodyMass(days: Int) async throws -> [BodyMassResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let kgUnit = HKUnit.gramUnit(with: .kilo)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.bodyMass),
                quantitySamplePredicate: predicate,
                options: [.discreteAverage],
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                var data: [BodyMassResult] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    let kg = avg.doubleValue(for: kgUnit)
                    let lbs = round(kg * 2.20462 * 10) / 10
                    data.append(BodyMassResult(date: formatter.string(from: stats.startDate), weight_lbs: lbs))
                }
                continuation.resume(returning: data)
            }
            store.execute(q)
        }
    }

    // MARK: - Sleep

    func querySleep(days: Int) async throws -> [SleepResult] {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let store = self.store

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let categorySamples = (samples ?? []).compactMap { $0 as? HKCategorySample }
                continuation.resume(returning: sleepResults(from: categorySamples))
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

// MARK: - Sleep aggregation helper

func sleepResults(from samples: [HKCategorySample], calendar: Calendar = .current) -> [SleepResult] {
    typealias Acc = (inBed: Double, totalSleep: Double, core: Double, rem: Double, deep: Double, awake: Double)
    var byDay: [Date: Acc] = [:]

    for sample in samples {
        // Use noon-boundary: samples starting before noon are attributed to the previous calendar day's
        // night (e.g. 1am May 5 → "May 4 night"). Samples starting at noon or after start a new night.
        let startOfDay = calendar.startOfDay(for: sample.startDate)
        let noonOfDay = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
        let day = sample.startDate < noonOfDay
            ? calendar.date(byAdding: .day, value: -1, to: startOfDay)!
            : startOfDay
        let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
        var e = byDay[day] ?? (0, 0, 0, 0, 0, 0)
        switch sample.value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            e.inBed += minutes
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            e.totalSleep += minutes
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            e.totalSleep += minutes; e.core += minutes
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            e.totalSleep += minutes; e.rem += minutes
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            e.totalSleep += minutes; e.deep += minutes
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            e.awake += minutes
        default:
            break
        }
        byDay[day] = e
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = calendar.timeZone

    return byDay
        .filter { $0.value.inBed > 0 || $0.value.totalSleep > 0 }
        .sorted { $0.key < $1.key }
        .map { day, e in
            SleepResult(
                date: formatter.string(from: day),
                total_sleep_minutes: e.totalSleep,
                time_in_bed_minutes: e.inBed,
                stages: SleepStagesResult(
                    awake_minutes: e.awake > 0 ? e.awake : nil,
                    rem_minutes: e.rem > 0 ? e.rem : nil,
                    core_minutes: e.core > 0 ? e.core : nil,
                    deep_minutes: e.deep > 0 ? e.deep : nil
                )
            )
        }
}

// MARK: - Workout detail helpers

private func splitResults(from workout: HKWorkout, totalDistance: Double) -> [SplitResult]? {
    guard totalDistance > 0 else { return nil }
    let segments = (workout.workoutEvents ?? []).filter { $0.type == .segment }
    guard !segments.isEmpty else { return nil }
    // HealthKit auto-lap emits one .segment event per completed mile, so segment index i
    // corresponds to miles [i, i+1). The last segment covers the fractional remainder.
    var results: [SplitResult] = []
    for (i, event) in segments.enumerated() {
        let duration = event.dateInterval.duration
        let elapsed = event.dateInterval.end.timeIntervalSince(workout.startDate)
        let distance: Double
        if i == segments.count - 1 {
            let remaining = totalDistance - Double(i)
            guard remaining >= 0.05 else { continue }
            distance = remaining
        } else {
            distance = 1.0
        }
        results.append(SplitResult(
            mile: i + 1,
            pace_sec_per_mile: duration / distance,
            elapsed_seconds: elapsed
        ))
    }
    return results.isEmpty ? nil : results
}

func activityTypeLabel(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .cooldown: return "cooldown"
    case .preparationAndRecovery: return "recovery"
    case .running: return "run"
    case .walking: return "walk"
    default: return "segment"
    }
}

private func intervalResults(from workout: HKWorkout) -> [IntervalResult]? {
    let activities = workout.workoutActivities.filter { $0.duration > 0 }
    guard !activities.isEmpty else { return nil }
    let hrUnit = HKUnit(from: "count/min")
    return activities.enumerated().map { index, activity in
        let duration = activity.duration
        let dist = activity.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .mile())
        let pace: Double? = dist.flatMap { d in d > 0 ? duration / d : nil }
        let hr = activity.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: hrUnit)
        return IntervalResult(
            index: index,
            type: activityTypeLabel(activity.workoutConfiguration.activityType),
            duration_seconds: duration,
            distance_miles: dist,
            pace_sec_per_mile: pace,
            avg_heart_rate_bpm: hr.flatMap { $0 > 0 ? $0 : nil }
        )
    }
}
