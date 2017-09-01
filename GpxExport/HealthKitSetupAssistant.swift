
import HealthKit

class HealthKitSetupAssistant {
    
    private enum HealthkitSetupError: Error {
        case notAvailableOnDevice
        case dataTypeNotAvailable
    }
    
    class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
        
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }
        
        let healthKitTypesToWrite: Set<HKSampleType> = []
        
        let healthKitTypesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        ]
        
        HKHealthStore().requestAuthorization(
            toShare: healthKitTypesToWrite,
            read: healthKitTypesToRead
        ){
            (success, error) in
            completion(success, error)
        }
    }
}
