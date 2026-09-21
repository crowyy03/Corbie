import CorbieCore
import Foundation
import os

@MainActor
enum PairingStepLog {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    static func measure<T>(_ name: String, _ work: () async throws -> T) async rethrows -> T {
        PairingStepLog.log.notice("\(name, privacy: .public) started")
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let value = try await work()
            let elapsed = milliseconds(start.duration(to: clock.now))
            PairingStepLog.log.notice("\(name, privacy: .public) took \(elapsed, privacy: .public) ms")
            return value
        } catch {
            let elapsed = milliseconds(start.duration(to: clock.now))
            PairingStepLog.log.error("\(name, privacy: .public) failed after \(elapsed, privacy: .public) ms")
            throw error
        }
    }

    nonisolated static func milliseconds(_ duration: Duration) -> Int64 {
        let parts = duration.components
        return parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000
    }
}
