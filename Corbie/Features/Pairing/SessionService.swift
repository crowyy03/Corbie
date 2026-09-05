import CorbieCore
import Foundation

struct SessionService: Sendable {
    struct Token: Sendable, Equatable, Decodable {
        let token: String
        let expiresAt: Date
    }

    static let path = "session"

    private let configuration: ServerConfiguration
    private let session: URLSession
    private let appVersion: String

    init(
        configuration: ServerConfiguration,
        session: URLSession = URLSessionTransport.makeSession(),
        appVersion: String = AppVersion.current()
    ) {
        self.configuration = configuration
        self.session = session
        self.appVersion = appVersion
    }

    var isConfigured: Bool { configuration.isPlaceholder == false }

    func exchange(appleIdentityToken: String) async throws -> Token {
        guard isConfigured else {
            throw CorbieError.network("server url is not configured")
        }
        guard appleIdentityToken.isEmpty == false else {
            throw CorbieError.auth("apple identity token is empty")
        }
        var request = URLRequest(url: configuration.url(path: SessionService.path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(appleIdentityToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.httpBody = Data("{}".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CorbieError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CorbieError.network("no http response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw SessionService.failure(status: http.statusCode, body: data)
        }
        do {
            return try CorbieJSON.decoder.decode(Token.self, from: data)
        } catch {
            throw CorbieError.network("session response is not readable")
        }
    }

    static func failure(status: Int, body: Data) -> CorbieError {
        let envelope = try? CorbieJSON.decoder.decode(ServerErrorEnvelope.self, from: body)
        let detail = envelope?.message ?? "status \(status)"
        if status == 401 || envelope?.code == .unauthorized {
            return .auth(detail)
        }
        return .network(detail)
    }
}
