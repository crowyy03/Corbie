import AuthenticationServices
import CorbieCore
import Foundation
import os

struct AppleCredentialMonitor: Sendable {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "account")

    @MainActor
    func verifyStoredCredential(_ environment: AppEnvironment) async {
        #if DEBUG
        if environment.isScreenshotMode { return }
        #endif
        guard let userIdentifier = environment.identity.currentAppleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await provider.credentialState(forUserID: userIdentifier)
        } catch {
            let failure = error as NSError
            AppleCredentialMonitor.log.notice(
                "apple credential check: no answer, \(failure.domain, privacy: .public) \(failure.code, privacy: .public)"
            )
            return
        }
        AppleCredentialMonitor.log.notice("apple credential check: \(AppleCredentialMonitor.name(of: state), privacy: .public)")
        guard state == .revoked else { return }
        environment.signOut()
    }

    @MainActor
    func observeRevocation(_ environment: AppEnvironment) async {
        let revocations = NotificationCenter.default.notifications(
            named: ASAuthorizationAppleIDProvider.credentialRevokedNotification
        )
        for await _ in revocations {
            environment.signOut()
        }
    }

    static func name(of state: ASAuthorizationAppleIDProvider.CredentialState) -> String {
        switch state {
        case .authorized: return "authorized"
        case .revoked: return "revoked"
        case .notFound: return "not found"
        case .transferred: return "transferred"
        @unknown default: return "unknown \(state.rawValue)"
        }
    }
}
