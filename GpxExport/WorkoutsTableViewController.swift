import UIKit
import HealthKit
import WatchKit

class WorkoutsTableViewController: UITableViewController {

  private enum WorkoutsSegues: String {
    case showCreateWorkout
    case finishedCreatingWorkout
  }

    lazy private var workoutStore: WorkoutDataStore = {
        return WorkoutDataStore()
    }()

  private var workouts: [HKWorkout]?

  private let prancerciseWorkoutCellID = "PrancerciseWorkoutCell"

  lazy var dateFormatter:DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium
    return formatter
  }()

  lazy var filenameDateFormatter: DateFormatter = {
    let formatter = DateFormatter();
    formatter.dateFormat = "yyyy-MM-dd hh.mm.ss"
    return formatter;
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    self.clearsSelectionOnViewWillAppear = false
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    reloadWorkouts()
  }

  func reloadWorkouts() {

    workoutStore.loadWorkouts() { (workouts, error) in
      self.workouts = workouts
      self.tableView.reloadData()
    }
  }

  //MARK: UITableView DataSource
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

    guard let workouts = workouts else {
      return 0
    }

    return workouts.count
  }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath);
        guard let workouts = self.workouts else {
            return;
        }

        if (indexPath.row >= workouts.count){
            return;
        }

        print(indexPath.row)
        let workout = workouts[indexPath.row];
        let workout_name: String = {
            switch workout.workoutActivityType {
                case .cycling: return "Cycle"
                case .running: return "Run"
                case .walking: return "Walk"
                default: return "Workout"
            }
        }()
        let workout_title = "\(workout_name) - \(self.dateFormatter.string(from: workout.startDate))"
        let file_name = "\(self.filenameDateFormatter.string(from: workout.startDate)) - \(workout_name)"

        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(file_name)
            .appendingPathExtension("gpx")

        let file: FileHandle

        do {
            let manager = FileManager.default;
            if manager.fileExists(atPath: targetURL.path){
                try manager.removeItem(atPath: targetURL.path)
            }
            print(manager.createFile(atPath: targetURL.path, contents: Data()))
            file = try FileHandle(forWritingTo: targetURL);
        }catch let err {
            print(err)
            return
        }

        workoutStore.heartRate(for: workouts[indexPath.row]){
            (rates, error) in

            guard let keyedRates = rates, error == nil else {
                print(error as Any);
                return
            }

            let iso_formatter = ISO8601DateFormatter()
            var current_heart_rate_index = 0;
            var current_hr: Double = -1;
            let bpm_unit = HKUnit(from: "count/min")
            var hr_string = "";
            file.write(
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"Apple Workouts (via pilif's hack of the week)\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://www.topografix.com/GPX/1/1\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\" xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\"><trk><name><![CDATA[\(workout_title)]]></name><time>\(iso_formatter.string(from: workout.startDate))</time><trkseg>"
                        .data(using: .utf8)!
            )

            self.workoutStore.route(for: workouts[indexPath.row]){
                (maybe_locations, error) in
                guard let locations = maybe_locations, error == nil else {
                    print(error as Any);
                    file.closeFile()
                    return
                }

                for location in locations {
                    while (current_heart_rate_index < keyedRates.count) && (location.timestamp > keyedRates[current_heart_rate_index].startDate) {
                        current_hr = keyedRates[current_heart_rate_index].quantity.doubleValue(for: bpm_unit)
                        current_heart_rate_index += 1;
                        hr_string = "<extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>\(current_hr)</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>"
                    }

                    file.write(
                        "<trkpt lat=\"\(location.coordinate.latitude)\" lon=\"\(location.coordinate.longitude)\"><ele>\(location.altitude.magnitude)</ele><time>\(iso_formatter.string(from: location.timestamp))</time>\(hr_string)</trkpt>"
                            .data(using: .utf8)!
                    )
                }
                file.write("</trkseg></trk></gpx>".data(using: .utf8)!)
                file.closeFile()

                let activityViewController = UIActivityViewController( activityItems: [targetURL],
                                                                       applicationActivities: nil)
                if let popoverPresentationController = activityViewController.popoverPresentationController {
                    popoverPresentationController.barButtonItem = nil
                }
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
    }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    guard let workouts = workouts else {
      fatalError("CellForRowAtIndexPath should never get called if there are no workouts")
    }

    //1. Get a cell to display the workout in.
    let cell = tableView.dequeueReusableCell(withIdentifier: prancerciseWorkoutCellID,
                                             for: indexPath)

    //2. Get the workout corresponding to this row.
    let workout = workouts[indexPath.row]

    //3. Show the workout's start date in the label.
    cell.textLabel?.text = dateFormatter.string(from: workout.startDate)

    //4. Show the Calorie burn in the lower label.
    if let caloriesBurned = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) {
      let formattedCalories = String(format: "CaloriesBurned: %.2f", caloriesBurned)
      cell.detailTextLabel?.text = formattedCalories
    } else {
      cell.detailTextLabel?.text = nil
    }

    return cell
  }
}
