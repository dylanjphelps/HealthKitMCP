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

    func isAuthorized() -> Bool {
        store.authorizationStatus(for: HKQuantityType(.stepCount)) == .sharingAuthorized
    }

    func guardAvailableAndAuthorized() -> String? {
        guard Self.isAvailable else {
            return "HealthKit is not available on this device"
        }
        guard isAuthorized() else {
            return "HealthKit authorization not granted — open HealthKitMCP.app to authorize"
        }
        return nil
    }

    // MARK: - Workout Query

    func queryWorkouts(from startDate: Date, to endDate: Date) async throws -> Result<[WorkoutRecord], String> {
        if let error = guardAvailableAndAuthorized() { return .failure(error) }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
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

        let records = (samples as? [HKWorkout] ?? [])
            .filter { $0.workoutActivityType == .running }
            .map { self.toWorkoutRecord($0) }

        if records.isEmpty {
            return .failure("No data found for the requested date range")
        }
        return .success(records)
    }

    private func toWorkoutRecord(_ workout: HKWorkout) -> WorkoutRecord {
        let distanceKm = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
        let durationMin = workout.duration / 60
        let paceSecPerKm = distanceKm > 0 ? workout.duration / distanceKm : 0
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0

        let hrStats = workout.statistics(for: HKQuantityType(.heartRate))
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

    func queryActivitySummary(from startDate: Date, to endDate: Date) async throws -> Result<[ActivitySummaryRecord], String> {
        if let error = guardAvailableAndAuthorized() { return .failure(error) }

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

            records.append(ActivitySummaryRecord(
                date: DateHelpers.isoDay.string(from: date),
                steps: Int(steps),
                active_energy_kcal: energy,
                exercise_minutes: Int(exercise)
            ))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endDay
        }

        if records.allSatisfy({ $0.steps == 0 && $0.active_energy_kcal == 0 && $0.exercise_minutes == 0 }) {
            return .failure("No data found for the requested date range")
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

    func queryRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> Result<[HeartRateRecord], String> {
        if let error = guardAvailableAndAuthorized() { return .failure(error) }

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
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endDay
        }

        if records.isEmpty {
            return .failure("No data found for the requested date range")
        }
        return .success(records)
    }

    // MARK: - VO2 Max

    func queryVO2Max() async throws -> Result<VO2MaxRecord, String> {
        if let error = guardAvailableAndAuthorized() { return .failure(error) }

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
            return .failure("No data found for the requested date range")
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
