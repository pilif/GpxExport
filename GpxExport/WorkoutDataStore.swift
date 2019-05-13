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
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: HKQueryOptions.strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let heartRateQuery = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
            (query, samples, error) in
            
            guard let heartRateSamples: [HKQuantitySample] = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            if (heartRateSamples.count == 0){
                print("Got no heart rate samples. Too bad")
                completion([HKQuantitySample](), nil);
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
    
    public func route(for workout: HKWorkout, completion: @escaping (([CLLocation]?, Error?) -> Swift.Void)){
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

            if (routeSamples.count == 0){
                completion([CLLocation](), nil)
                return;
            }
            var sampleCounter = 0
            var routeLocations:[CLLocation] = []

            for routeSample: HKWorkoutRoute in routeSamples {
                
                let locationQuery: HKWorkoutRouteQuery = HKWorkoutRouteQuery(route: routeSample) { _, locationResults, done, error in
                    guard locationResults != nil else {
                        print("Error occured while querying for locations: \(error?.localizedDescription ?? "")")
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                        return
                    }

                    if done {
                        sampleCounter += 1
                        if sampleCounter != routeSamples.count {
                            if let locations = locationResults {
                                routeLocations.append(contentsOf: locations)
                            }
                        } else {
                            if let locations = locationResults {
                                routeLocations.append(contentsOf: locations)
                                let sortedLocations = routeLocations.sorted(by: {$0.timestamp < $1.timestamp})
                                DispatchQueue.main.async {
                                    completion(sortedLocations, error)
                                }
                            }
                        }
                    } else {
                        if let locations = locationResults {
                            routeLocations.append(contentsOf: locations)
                        }
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
            HKQuery.predicateForWorkouts(with: .hiking)
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
