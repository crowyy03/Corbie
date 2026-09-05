import AuthenticationServices
import Foundation

struct AppleCredentialMonitor: Sendable {
    @MainActor
    func verifyStoredCredential(_ environment: AppEnvironment) async {
        guard let userIdentifier = environment.identity.currentAppleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        guard let state = try? await provider.credentialState(forUserID: userIdentifier) else { return }
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
}
