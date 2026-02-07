import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

@Observable
final class HealthKitService {
    var isAvailable: Bool = false
    var isAuthorized: Bool = false

    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    #endif

    init() {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            isAvailable = true
        }
        #endif
    }

    func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard let healthStore else { return false }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: [])
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    func logWorkout(
        activityType: Int,
        duration: TimeInterval,
        startDate: Date
    ) async -> Bool {
        #if canImport(HealthKit)
        guard let healthStore, isAuthorized else { return false }

        let workoutType = HKWorkoutActivityType(rawValue: UInt(activityType)) ?? .functionalStrengthTraining
        let endDate = startDate.addingTimeInterval(duration)

        let workout = HKWorkout(
            activityType: workoutType,
            start: startDate,
            end: endDate
        )

        do {
            try await healthStore.save(workout)
            return true
        } catch {
            print("HealthKit save error: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    static func activityTypeName(_ rawValue: Int?) -> String {
        guard let rawValue else { return "General" }
        switch rawValue {
        case 20: return "Core Training"   // coreTraining
        case 37: return "Walking"          // walking
        case 52: return "Flexibility"      // flexibility
        case 13: return "Strength"         // functionalStrengthTraining
        default: return "General"
        }
    }
}
