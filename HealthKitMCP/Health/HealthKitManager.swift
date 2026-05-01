// HealthKitMCP/Health/HealthKitManager.swift
import HealthKit
import Foundation

actor HealthKitManager {
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
        ]
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // Returns true if the user has been shown the authorization prompt.
    // HealthKit does not distinguish between "authorized" and "denied" for read-only
    // types — both appear as .unnecessary after the prompt has been shown once.
    func isAuthorized() async -> Bool {
        guard Self.isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
        return status == .unnecessary
    }

    private func guardAvailableAndAuthorized() async throws -> HKMCPError? {
        guard Self.isAvailable else {
            return HKMCPError(message: "HealthKit is not available on this device")
        }
        let status = try await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
        if status == .shouldRequest {
            return HKMCPError(message: "HealthKit authorization not granted — open HealthKitMCP.app to authorize")
        }
        return nil
    }

    // MARK: - Workout Query

    func queryWorkouts(from startDate: Date, to endDate: Date) async throws -> Result<[WorkoutRecord], HKMCPError> {
        if let error = try await guardAvailableAndAuthorized() { return .failure(error) }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, runningPredicate])
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }

        let records = (samples as? [HKWorkout] ?? []).map { self.toWorkoutRecord($0) }

        if records.isEmpty {
            return .failure(HKMCPError(message: "No data found for the requested date range"))
        }
        return .success(records)
    }

    private func toWorkoutRecord(_ workout: HKWorkout) -> WorkoutRecord {
        let distanceStats = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))
        let energyStats = workout.statistics(for: HKQuantityType(.activeEnergyBurned))
        let hrStats = workout.statistics(for: HKQuantityType(.heartRate))

        let distanceKm = distanceStats?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
        let durationMin = workout.duration / 60
        let paceSecPerKm = distanceKm > 0 ? workout.duration / distanceKm : 0
        let calories = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

        let bpm = HKUnit.count().unitDivided(by: .minute())
        let avgHR = hrStats?.averageQuantity()?.doubleValue(for: bpm)
        let maxHR = hrStats?.maximumQuantity()?.doubleValue(for: bpm)

        return WorkoutRecord(
            date: DateHelpers.isoDay.string(from: workout.startDate),
            duration_minutes: durationMin,
            distance_km: distanceKm,
            avg_pace_sec_per_km: paceSecPerKm,
            avg_heart_rate_bpm: avgHR,
            max_heart_rate_bpm: maxHR,
            active_calories_kcal: calories
        )
    }

    // MARK: - Activity Summary

    func queryActivitySummary(from startDate: Date, to endDate: Date) async throws -> Result<[ActivitySummaryRecord], HKMCPError> {
        if let error = try await guardAvailableAndAuthorized() { return .failure(error) }

        var intervalComponents = DateComponents()
        intervalComponents.day = 1

        let stepsType = HKQuantityType(.stepCount)
        let energyType = HKQuantityType(.activeEnergyBurned)
        let exerciseType = HKQuantityType(.appleExerciseTime)

        async let stepsResult = statisticsCollection(for: stepsType, from: startDate, to: endDate, intervalComponents: intervalComponents)
        async let energyResult = statisticsCollection(for: energyType, from: startDate, to: endDate, intervalComponents: intervalComponents)
        async let exerciseResult = statisticsCollection(for: exerciseType, from: startDate, to: endDate, intervalComponents: intervalComponents)

        let (stepsCollection, energyCollection, exerciseCollection) = try await (stepsResult, energyResult, exerciseResult)

        let calendar = Calendar.current
        var records: [ActivitySummaryRecord] = []
        var date = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while date <= endDay {
            let steps = stepsCollection.statistics(for: date)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            let energy = energyCollection.statistics(for: date)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            let exercise = exerciseCollection.statistics(for: date)?.sumQuantity()?.doubleValue(for: .minute()) ?? 0

            if steps > 0 || energy > 0 || exercise > 0 {
                records.append(ActivitySummaryRecord(
                    date: DateHelpers.isoDay.string(from: date),
                    steps: Int(steps),
                    active_energy_kcal: energy,
                    exercise_minutes: Int(exercise)
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        if records.isEmpty {
            return .failure(HKMCPError(message: "No data found for the requested date range"))
        }
        return .success(records)
    }

    private func statisticsCollection(
        for type: HKQuantityType,
        from startDate: Date,
        to endDate: Date,
        intervalComponents: DateComponents
    ) async throws -> HKStatisticsCollection {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: startDate),
                intervalComponents: intervalComponents
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                guard let collection else {
                    continuation.resume(throwing: HKError(.errorNoData))
                    return
                }
                continuation.resume(returning: collection)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart Rate

    func queryRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> Result<[HeartRateRecord], HKMCPError> {
        if let error = try await guardAvailableAndAuthorized() { return .failure(error) }

        var intervalComponents = DateComponents()
        intervalComponents.day = 1

        let restingHRType = HKQuantityType(.restingHeartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let collection: HKStatisticsCollection = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: restingHRType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMin, .discreteMax],
                anchorDate: Calendar.current.startOfDay(for: startDate),
                intervalComponents: intervalComponents
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                guard let collection else {
                    continuation.resume(throwing: HKError(.errorNoData))
                    return
                }
                continuation.resume(returning: collection)
            }
            store.execute(query)
        }

        let bpm = HKUnit.count().unitDivided(by: .minute())
        let calendar = Calendar.current
        var records: [HeartRateRecord] = []
        var date = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while date <= endDay {
            if let stats = collection.statistics(for: date),
               let avg = stats.averageQuantity()?.doubleValue(for: bpm),
               let min = stats.minimumQuantity()?.doubleValue(for: bpm),
               let max = stats.maximumQuantity()?.doubleValue(for: bpm) {
                records.append(HeartRateRecord(
                    date: DateHelpers.isoDay.string(from: date),
                    avg_resting_hr_bpm: avg,
                    min_resting_hr_bpm: min,
                    max_resting_hr_bpm: max
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        if records.isEmpty {
            return .failure(HKMCPError(message: "No data found for the requested date range"))
        }
        return .success(records)
    }

    // MARK: - VO2 Max

    func queryVO2Max() async throws -> Result<VO2MaxRecord, HKMCPError> {
        if let error = try await guardAvailableAndAuthorized() { return .failure(error) }

        let vo2Type = HKQuantityType(.vo2Max)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }

        guard let sample = samples.first as? HKQuantitySample else {
            return .failure(HKMCPError(message: "No VO2 max data available — this value is recorded by Apple Watch during outdoor runs."))
        }

        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        let value = sample.quantity.doubleValue(for: unit)

        return .success(VO2MaxRecord(
            value_ml_per_kg_per_min: value,
            date: DateHelpers.isoDay.string(from: sample.startDate),
            source: sample.sourceRevision.source.name
        ))
    }
}
