import CorbieCore
import Foundation
import Network
import Observation

@MainActor
@Observable
final class WishesNetworkMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { path in
            let isSatisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = isSatisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: CorbieIdentifiers.bundleID + ".wishes.network"))
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
