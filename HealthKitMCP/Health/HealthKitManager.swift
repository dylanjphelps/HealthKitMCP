import HealthKit
import Foundation
import CoreLocation

enum HealthKitError: Error {
    case invalidDateRange
}

actor HealthKitManager {
    private let store = HKHealthStore()

    // MARK: - Authorization

    // HKSampleType subset — used for statusForAuthorizationRequest (excludes activitySummaryType)
    private static let readSampleTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),
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

    // MARK: - Workouts

    func queryWorkouts(days: Int) async throws -> [WorkoutResult] {
        let store = self.store
        let workouts = try await fetchRunningWorkouts(days: days)

        let iso = ISO8601DateFormatter()
        let hrUnit = HKUnit(from: "count/min")

        var results: [WorkoutResult] = []
        for w in workouts {
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
            let splits = try await splitResults(from: w, store: store)
            let intervals = intervalResults(from: w)
            results.append(WorkoutResult(
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
            ))
        }
        return results
    }

    // MARK: - Activity Summary

    func queryActivitySummary(days: Int) async throws -> [ActivitySummaryResult] {
        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }

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
                        dict[fullDateString(from: stats.startDate)] = sum.doubleValue(for: .count())
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
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let unit = HKUnit(from: "count/min")
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
                        date: fullDateString(from: stats.startDate),
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
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let unit = HKUnit.secondUnit(with: .milli)
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
                        date: fullDateString(from: stats.startDate),
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
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let interval = DateComponents(day: 1)
        let anchor = Calendar.current.startOfDay(for: start)
        let lbsUnit = HKUnit.pound()
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
                    let lbs = (avg.doubleValue(for: lbsUnit) * 10).rounded() / 10
                    data.append(BodyMassResult(date: fullDateString(from: stats.startDate), weight_lbs: lbs))
                }
                continuation.resume(returning: data)
            }
            store.execute(q)
        }
    }

    // MARK: - Sleep

    func querySleep(days: Int) async throws -> [SleepResult] {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }
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
                    date: timestampString(from: sample.startDate),
                    vo2max_ml_kg_min: sample.quantity.doubleValue(for: unit)
                ))
            }
            store.execute(q)
        }
    }

    // MARK: - Elevation (metadata with route fallback)

    func queryElevation(days: Int) async throws -> [ElevationResult] {
        let store = self.store
        let workouts = try await fetchRunningWorkouts(days: days)

        let iso = ISO8601DateFormatter()
        var results: [ElevationResult] = []

        for w in workouts {
            let distMiles = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .mile()) ?? 0
            var elevUp = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
                .doubleValue(for: .foot())
            var elevDown = (w.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity)?
                .doubleValue(for: .foot())

            if elevUp == nil && elevDown == nil {
                if let routeElev = try await routeElevation(for: w, store: store) {
                    elevUp = routeElev.ascentFeet
                    elevDown = routeElev.descentFeet
                }
            }

            results.append(ElevationResult(
                date: iso.string(from: w.startDate),
                total_ascent_feet: elevUp,
                total_descent_feet: elevDown,
                distance_miles: distMiles
            ))
        }

        return results
    }

    // MARK: - Heart Rate Zones

    func queryHeartRateZones(days: Int, boundaries: [Double]?) async throws -> [WorkoutHeartRateZonesResult] {
        let store = self.store
        let workouts = try await fetchRunningWorkouts(days: days)

        let iso = ISO8601DateFormatter()
        let hrUnit = HKUnit(from: "count/min")
        let zoneBoundaries = boundaries ?? QueryHeartRateZonesTool.defaultBoundaries
        let zoneLabels = boundaries != nil
            ? (1...(zoneBoundaries.count + 1)).map { "Zone \($0)" }
            : QueryHeartRateZonesTool.defaultLabels

        var results: [WorkoutHeartRateZonesResult] = []

        for w in workouts {
            let distMiles = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .mile()) ?? 0
            let hrSamples = try await fetchWorkoutHeartRateSamples(for: w, store: store)
            let readings: [(bpm: Double, durationSeconds: Double)] = hrSamples.enumerated().map { i, sample in
                let sampleEnd = i + 1 < hrSamples.count ? hrSamples[i + 1].startDate : w.endDate
                let duration = sampleEnd.timeIntervalSince(sample.startDate)
                return (bpm: sample.quantity.doubleValue(for: hrUnit), durationSeconds: max(0, duration))
            }
            let zones = computeHeartRateZones(readings: readings, boundaries: zoneBoundaries, labels: zoneLabels)
            results.append(WorkoutHeartRateZonesResult(
                date: iso.string(from: w.startDate),
                duration_minutes: w.duration / 60,
                distance_miles: distMiles,
                zones: zones
            ))
        }

        return results
    }

    private func fetchRunningWorkouts(days: Int) async throws -> [HKWorkout] {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            throw HealthKitError.invalidDateRange
        }
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
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
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
        var entry = byDay[day] ?? (inBed: 0, totalSleep: 0, core: 0, rem: 0, deep: 0, awake: 0)
        switch sample.value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            entry.inBed += minutes
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            entry.totalSleep += minutes
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            entry.totalSleep += minutes; entry.core += minutes
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            entry.totalSleep += minutes; entry.rem += minutes
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            entry.totalSleep += minutes; entry.deep += minutes
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            entry.awake += minutes
        default:
            break
        }
        byDay[day] = entry
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = calendar.timeZone

    return byDay
        .filter { $0.value.inBed > 0 || $0.value.totalSleep > 0 }
        .sorted { $0.key < $1.key }
        .map { day, entry in
            SleepResult(
                date: formatter.string(from: day),
                total_sleep_minutes: entry.totalSleep,
                time_in_bed_minutes: entry.inBed,
                stages: SleepStagesResult(
                    awake_minutes: entry.awake > 0 ? entry.awake : nil,
                    rem_minutes: entry.rem > 0 ? entry.rem : nil,
                    core_minutes: entry.core > 0 ? entry.core : nil,
                    deep_minutes: entry.deep > 0 ? entry.deep : nil
                )
            )
        }
}

// MARK: - Workout detail helpers

private func splitResults(from workout: HKWorkout, store: HKHealthStore) async throws -> [SplitResult]? {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

    async let distanceFetch: [HKQuantitySample] = withCheckedThrowingContinuation { continuation in
        let q = HKSampleQuery(
            sampleType: HKQuantityType(.distanceWalkingRunning),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, results, error in
            if let error { continuation.resume(throwing: error); return }
            continuation.resume(returning: results as? [HKQuantitySample] ?? [])
        }
        store.execute(q)
    }

    async let hrFetch: [HKQuantitySample] = withCheckedThrowingContinuation { continuation in
        let q = HKSampleQuery(
            sampleType: HKQuantityType(.heartRate),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, results, error in
            if let error { continuation.resume(throwing: error); return }
            continuation.resume(returning: results as? [HKQuantitySample] ?? [])
        }
        store.execute(q)
    }

    let (samples, hrSamples) = try await (distanceFetch, hrFetch)
    guard !samples.isEmpty else { return nil }

    let hrUnit = HKUnit(from: "count/min")

    var splits: [SplitResult] = []
    var cumulativeDistance = 0.0
    var mileStartDate = workout.startDate
    var currentMile = 1

    for sample in samples {
        let sampleDist = sample.quantity.doubleValue(for: .mile())
        let previousCumulative = cumulativeDistance
        cumulativeDistance += sampleDist

        while cumulativeDistance >= Double(currentMile) {
            // Interpolate time at which the mile boundary was crossed
            let distNeeded = Double(currentMile) - previousCumulative
            let fractionOfSample = sampleDist > 0 ? distNeeded / sampleDist : 1.0
            let sampleDuration = sample.endDate.timeIntervalSince(sample.startDate)
            let timeAtMile = sample.startDate.addingTimeInterval(sampleDuration * fractionOfSample)

            let mileDuration = timeAtMile.timeIntervalSince(mileStartDate)
            let elapsed = timeAtMile.timeIntervalSince(workout.startDate)
            let avgHR = averageHeartRate(from: hrSamples, unit: hrUnit, start: mileStartDate, end: timeAtMile)

            splits.append(SplitResult(
                mile: currentMile,
                pace_sec_per_mile: mileDuration,
                elapsed_seconds: elapsed,
                avg_heart_rate_bpm: avgHR
            ))

            mileStartDate = timeAtMile
            currentMile += 1
        }
    }

    // Final fractional mile
    let remaining = cumulativeDistance - Double(currentMile - 1)
    if remaining >= 0.05, let lastSample = samples.last {
        let elapsed = lastSample.endDate.timeIntervalSince(workout.startDate)
        let duration = lastSample.endDate.timeIntervalSince(mileStartDate)
        let avgHR = averageHeartRate(from: hrSamples, unit: hrUnit, start: mileStartDate, end: lastSample.endDate)
        splits.append(SplitResult(
            mile: currentMile,
            pace_sec_per_mile: duration / remaining,
            elapsed_seconds: elapsed,
            avg_heart_rate_bpm: avgHR
        ))
    }

    return splits.isEmpty ? nil : splits
}

/// Compute average heart rate from samples that overlap a time window.
private func averageHeartRate(from samples: [HKQuantitySample], unit: HKUnit, start: Date, end: Date) -> Double? {
    let matching = samples.filter { $0.startDate < end && $0.endDate > start }
    guard !matching.isEmpty else { return nil }
    let sum = matching.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
    let avg = sum / Double(matching.count)
    return avg > 0 ? avg : nil
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

private func fullDateString(from date: Date, calendar: Calendar = .current) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
}

private func timestampString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
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

// MARK: - Route elevation helpers

private func routeElevation(for workout: HKWorkout, store: HKHealthStore) async throws -> (ascentFeet: Double, descentFeet: Double)? {
    let routeType = HKSeriesType.workoutRoute()
    let predicate = HKQuery.predicateForObjects(from: workout)

    let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
        let q = HKSampleQuery(
            sampleType: routeType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            if let error { continuation.resume(throwing: error); return }
            continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
        }
        store.execute(q)
    }

    guard let route = routes.first else { return nil }

    let locations: [CLLocation] = try await withCheckedThrowingContinuation { continuation in
        var allLocations: [CLLocation] = []
        var hasResumed = false
        let q = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
            guard !hasResumed else { return }
            if let error {
                hasResumed = true
                continuation.resume(throwing: error)
                return
            }
            if let newLocations {
                allLocations.append(contentsOf: newLocations)
            }
            if done {
                hasResumed = true
                continuation.resume(returning: allLocations)
            }
        }
        store.execute(q)
    }

    let altitudes = locations
        .sorted { $0.timestamp < $1.timestamp }
        .map { $0.altitude }
    return computeRouteElevation(altitudes: altitudes)
}

private func fetchWorkoutHeartRateSamples(for workout: HKWorkout, store: HKHealthStore) async throws -> [HKQuantitySample] {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

    return try await withCheckedThrowingContinuation { continuation in
        let q = HKSampleQuery(
            sampleType: HKQuantityType(.heartRate),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, results, error in
            if let error { continuation.resume(throwing: error); return }
            continuation.resume(returning: results as? [HKQuantitySample] ?? [])
        }
        store.execute(q)
    }
}

// MARK: - Pure computation helpers (testable)

func computeHeartRateZones(
    readings: [(bpm: Double, durationSeconds: Double)],
    boundaries: [Double],
    labels: [String]
) -> [HeartRateZoneDetail] {
    let zoneCount = boundaries.count + 1
    var zoneDurations = Array(repeating: 0.0, count: zoneCount)

    for (bpm, duration) in readings {
        let zoneIndex = boundaries.lastIndex(where: { bpm >= $0 }).map { $0 + 1 } ?? 0
        zoneDurations[zoneIndex] += duration
    }

    let totalDuration = zoneDurations.reduce(0, +)

    return (0..<zoneCount).map { i in
        let rangeStr: String
        if i == 0 {
            rangeStr = "< \(Int(boundaries[0]))"
        } else if i < boundaries.count {
            rangeStr = "\(Int(boundaries[i - 1]))-\(Int(boundaries[i]) - 1)"
        } else {
            rangeStr = ">= \(Int(boundaries.last!))"
        }

        let label = i < labels.count ? labels[i] : "Zone \(i + 1)"
        let durationMinutes = zoneDurations[i] / 60.0
        let percentage = totalDuration > 0 ? (zoneDurations[i] / totalDuration) * 100.0 : 0.0

        return HeartRateZoneDetail(
            zone: i + 1,
            label: label,
            range_bpm: rangeStr,
            duration_minutes: durationMinutes,
            percentage: percentage
        )
    }
}
