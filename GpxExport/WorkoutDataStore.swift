import HealthKit
import WatchKit

class WorkoutDataStore {
    private var healthStore: HKHealthStore
    
    init(){
        healthStore = HKHealthStore()
    }
    
    public func heartRate(for workout: HKWorkout, completion: @escaping (([HKQuantitySample]?, Error?) -> Swift.Void)){
        var allSamples = Array<HKQuantitySample>()
        
        let hrType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let p = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let heartRateQuery = HKSampleQuery(sampleType: hrType, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            (query, samples, error) in
            
            guard let heartRateSamples: [HKQuantitySample] = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            if (heartRateSamples.count == 0){
                return;
            }
            print("Got \(heartRateSamples.count) heart rate samples");
            for heartRateSample in heartRateSamples {
                allSamples.append(heartRateSample)
            }
            DispatchQueue.main.async {
                completion(allSamples, nil)
            }
        }
        healthStore.execute(heartRateQuery)
    }
    
    public func route(for workout: HKWorkout, completion: @escaping (([CLLocation]?, Bool, Error?) -> Swift.Void)){
        let routeType = HKSeriesType.workoutRoute();
        let p = HKQuery.predicateForObjects(from: workout)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let q = HKSampleQuery(sampleType: routeType, predicate: p, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            (query, samples, error) in
            if let err = error {
                print(err)
                return
            }
            
            guard let routeSamples: [HKWorkoutRoute] = samples as? [HKWorkoutRoute] else { print("No route samples"); return }
            
            for routeSample: HKWorkoutRoute in routeSamples {
                
                let locationQuery: HKWorkoutRouteQuery = HKWorkoutRouteQuery(route: routeSample) { _, locationResults, done, error in
                    guard locationResults != nil else {
                        print("Error occured while querying for locations: \(error?.localizedDescription ?? "")")
                        DispatchQueue.main.async {
                            completion(nil, done, error)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completion(locationResults, done, error)
                    }
                }
                
                self.healthStore.execute(locationQuery)
            }
        }
        healthStore.execute(q)
    }
    
    func loadWorkouts(completion: @escaping (([HKWorkout]?, Error?) -> Swift.Void)){
        
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .walking),
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .cycling),
            HKQuery.predicateForWorkouts(with: .swimming),
            ])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ){
            (query, samples, error) in
            DispatchQueue.main.async {
                guard let samples = samples as? [HKWorkout], error == nil else {
                    completion(nil, error)
                    return
                }
                completion(samples, nil)
            }
        }
        healthStore.execute(query)
    }
    
}
