import CorbieCore
import Foundation

struct MapPlace: Equatable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double

    init(name: String, address: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(event: EventDTO) {
        guard let name = event.locationName, let latitude = event.latitude, let longitude = event.longitude else {
            return nil
        }
        self.init(name: name, address: event.address, latitude: latitude, longitude: longitude)
    }
}
