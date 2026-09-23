#if DEBUG
import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ScreenshotModeSwitch {
    enum Phase: Equatable {
        case real
        case preparing
        case on
    }

    private(set) var phase: Phase = .real
    private(set) var demo: AppEnvironment?

    @ObservationIgnored let real: AppEnvironment
    @ObservationIgnored let lifecycle: ScreenshotModeLifecycle
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let transport: (any HTTPTransport)?
    @ObservationIgnored private var bootstrapped: Set<ObjectIdentifier> = []
    @ObservationIgnored private var isSwitching = false

    init(
        real: AppEnvironment,
        appState: AppState,
        lifecycle: ScreenshotModeLifecycle = ScreenshotModeLifecycle(images: .bundled()),
        transport: (any HTTPTransport)? = nil
    ) {
        self.real = real
        self.appState = appState
        self.lifecycle = lifecycle
        self.transport = transport
    }

    var active: AppEnvironment? {
        switch phase {
        case .real: return real
        case .preparing: return nil
        case .on: return demo
        }
    }

    var isOn: Bool { phase != .real }

    var sessionId: String? { demo?.persistence.screenshotModeSession }

    func start(arguments: [String] = ProcessInfo.processInfo.arguments) {
        switch ScreenshotModeFlag.launchRequest(in: arguments) {
        case .on?:
            beginSwitchingOn { try await $0.enter() }
        case .off?:
            lifecycle.leave(returningTo: real.persistence, identity: real.identity)
        case nil:
            guard lifecycle.flag.isOn else { return }
            beginSwitchingOn { lifecycle in
                if let resumed = await lifecycle.resume() { return resumed }
                return try await lifecycle.enter()
            }
        }
    }

    func enter() async {
        await switchOn { try await $0.enter() }
    }

    func leave() async {
        guard phase == .on, isSwitching == false else { return }
        lifecycle.leave(returningTo: real.persistence, identity: real.identity)
        real.isParkedForScreenshotMode = false
        phase = .real
        resetNavigation()
        await retireDemo()
    }

    func bootstrap(_ environment: AppEnvironment) async {
        guard bootstrapped.insert(ObjectIdentifier(environment)).inserted else { return }
        await environment.bootstrap()
    }

    private func beginSwitchingOn(_ open: @escaping (ScreenshotModeLifecycle) async throws -> ScreenshotModeSession) {
        real.isParkedForScreenshotMode = true
        phase = .preparing
        Task { await switchOn(open) }
    }

    private func switchOn(_ open: (ScreenshotModeLifecycle) async throws -> ScreenshotModeSession) async {
        guard isSwitching == false else { return }
        isSwitching = true
        defer { isSwitching = false }
        real.isParkedForScreenshotMode = true
        phase = .preparing
        resetNavigation()
        await retireDemo()
        do {
            let session = try await open(lifecycle)
            demo = AppEnvironment.screenshotMode(
                session,
                theme: real.theme,
                intents: lifecycle.intents,
                transport: transport
            )
            phase = .on
        } catch {
            lifecycle.leave(returningTo: real.persistence, identity: real.identity)
            real.isParkedForScreenshotMode = false
            phase = .real
            real.report(error)
        }
        resetNavigation()
    }

    private func retireDemo() async {
        guard let retired = demo else { return }
        demo = nil
        retired.isParkedForScreenshotMode = true
        bootstrapped.remove(ObjectIdentifier(retired))
        await retired.remoteChanges.stop()
    }

    private func resetNavigation() {
        appState.isUsHubPresented = false
        appState.route = nil
        appState.selectedTab = .today
    }
}
#endif
