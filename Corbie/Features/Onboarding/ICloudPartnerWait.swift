import CorbieCore
import Foundation
import os

protocol SpaceImportWatch: Sendable {
    func outcome(within timeout: Duration) async -> CloudKitSyncOutcome
}

extension CloudKitImportWatch: SpaceImportWatch {}

@MainActor
protocol SpaceImportWatching {
    var isMirrored: Bool { get }
    func iCloudAccount() async -> CloudKitSharing.ICloudAccount
    func watchImport(intoStoreHolding spaceId: UUID) async -> (any SpaceImportWatch)?
}

@MainActor
struct CloudKitSpaceImports: SpaceImportWatching {
    let stack: CoreDataStack
    let sharing: CloudKitSharing

    var isMirrored: Bool { stack.mirroring == .cloudKit }

    func iCloudAccount() async -> CloudKitSharing.ICloudAccount {
        await sharing.iCloudAccount()
    }

    func watchImport(intoStoreHolding spaceId: UUID) async -> (any SpaceImportWatch)? {
        await stack.watchImport(intoStoreHolding: spaceId)
    }
}

@MainActor
struct ICloudPartnerWait {
    enum Outcome: Equatable {
        case partnerFound
        case noPartner
        case importFailed(String)
        case timedOut
        case skipped(SkipReason)

        var logText: String {
            switch self {
            case .partnerFound: return "partner found"
            case .noPartner: return "partner none"
            case let .importFailed(reason): return "partner none, import failed: \(reason)"
            case .timedOut: return "timed out"
            case let .skipped(reason): return "skipped, \(reason.rawValue)"
            }
        }
    }

    enum SkipReason: String {
        case spaceMadeHere = "space made on this phone"
        case notMirrored = "no CloudKit mirroring"
        case noAccount = "no iCloud account"
        case accountBusy = "iCloud busy"
    }

    static let ceiling: Duration = .seconds(3)
    static let progressDelay: Duration = .milliseconds(400)

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    let imports: any SpaceImportWatching
    let clock: any Clock<Duration>

    func run(
        spaceId: UUID,
        spaceMadeHere: Bool,
        changes: StoreChanges,
        partnerIsStored: @escaping @MainActor () async -> Bool,
        onSlow: @escaping @MainActor () -> Void
    ) async {
        let elapsed = clock.stopwatch()
        let outcome: Outcome
        if spaceMadeHere {
            outcome = .skipped(.spaceMadeHere)
        } else if imports.isMirrored == false {
            outcome = .skipped(.notMirrored)
        } else {
            outcome = await race(spaceId: spaceId, changes: changes, partnerIsStored: partnerIsStored, onSlow: onSlow)
        }
        let milliseconds = PairingStepLog.milliseconds(elapsed())
        ICloudPartnerWait.log.notice(
            "invite: waited \(milliseconds, privacy: .public) ms for iCloud, \(outcome.logText, privacy: .public)"
        )
    }

    private func race(
        spaceId: UUID,
        changes: StoreChanges,
        partnerIsStored: @escaping @MainActor () async -> Bool,
        onSlow: @escaping @MainActor () -> Void
    ) async -> Outcome {
        let first = FirstOutcome()
        let sources = [
            Task {
                guard (try? await clock.sleep(for: ICloudPartnerWait.ceiling)) != nil else { return }
                first.settle(.timedOut)
            },
            Task {
                guard (try? await clock.sleep(for: ICloudPartnerWait.progressDelay)) != nil, first.isOpen else { return }
                onSlow()
            },
            Task {
                let stored = changes.stream()
                if await partnerIsStored() {
                    first.settle(.partnerFound)
                    return
                }
                for await _ in stored {
                    guard await partnerIsStored() else { continue }
                    first.settle(.partnerFound)
                    return
                }
            },
            Task {
                guard let outcome = await importOutcome(spaceId: spaceId, partnerIsStored: partnerIsStored) else { return }
                first.settle(outcome)
            }
        ]
        let outcome = await first.value
        sources.forEach { $0.cancel() }
        return outcome
    }

    private func importOutcome(
        spaceId: UUID,
        partnerIsStored: @MainActor () async -> Bool
    ) async -> Outcome? {
        guard let watch = await imports.watchImport(intoStoreHolding: spaceId) else {
            return .skipped(.notMirrored)
        }
        switch await imports.iCloudAccount() {
        case .missing: return .skipped(.noAccount)
        case .busy: return .skipped(.accountBusy)
        case .available, .unknown: break
        }
        let imported = await watch.outcome(within: ICloudPartnerWait.ceiling)
        guard Task.isCancelled == false else { return nil }
        if await partnerIsStored() { return .partnerFound }
        switch imported {
        case .finished: return .noPartner
        case let .failed(reason): return .importFailed(reason)
        case .timedOut: return nil
        }
    }
}

private extension Clock where Duration == Swift.Duration {
    func stopwatch() -> () -> Swift.Duration {
        let start = now
        return { start.duration(to: self.now) }
    }
}

@MainActor
private final class FirstOutcome {
    private var outcome: ICloudPartnerWait.Outcome?
    private var waiter: CheckedContinuation<ICloudPartnerWait.Outcome, Never>?

    var isOpen: Bool { outcome == nil }

    var value: ICloudPartnerWait.Outcome {
        get async {
            if let outcome { return outcome }
            return await withCheckedContinuation { waiter = $0 }
        }
    }

    func settle(_ settled: ICloudPartnerWait.Outcome) {
        guard outcome == nil else { return }
        outcome = settled
        waiter?.resume(returning: settled)
        waiter = nil
    }
}
