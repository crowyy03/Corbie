import CorbieCore
import CoreLocation

extension MapPlace {
    init?(task: TaskDTO) {
        guard let name = task.placeName, let latitude = task.lat, let longitude = task.lon else { return nil }
        self.init(name: name, address: task.address, latitude: latitude, longitude: longitude)
    }
}

extension TaskDTO {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
