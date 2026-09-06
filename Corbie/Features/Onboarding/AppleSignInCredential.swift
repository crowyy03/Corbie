import AuthenticationServices
import Foundation

struct AppleSignInCredential: Equatable {
    let userIdentifier: String
    let identityToken: String?
    let authorizationCode: String?
    let displayName: String?

    init(userIdentifier: String, identityToken: String?, authorizationCode: String?, displayName: String?) {
        self.userIdentifier = userIdentifier
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.displayName = displayName
    }

    init(credential: ASAuthorizationAppleIDCredential) {
        self.init(
            userIdentifier: credential.user,
            identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            displayName: AppleSignInCredential.displayName(from: credential.fullName)
        )
    }

    init?(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
        self.init(credential: credential)
    }

    static func isCancellation(_ error: any Error) -> Bool {
        guard let failure = error as? ASAuthorizationError else { return false }
        return failure.code == .canceled
    }

    static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        if let given = components.givenName?.trimmingCharacters(in: .whitespacesAndNewlines), given.isEmpty == false {
            return given
        }
        let full = components.formatted(.name(style: .medium)).trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? nil : full
    }
}
