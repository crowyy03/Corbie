import Foundation
import UIKit

struct SupportMail: Equatable {
    let address: String
    let subject: String
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    let appBuild: String

    static func current(bundle: Bundle = .main, device: UIDevice = .current) -> SupportMail {
        let info = bundle.infoDictionary
        return SupportMail(
            address: String(localized: "settings.support.address"),
            subject: String(localized: "settings.support.subject"),
            deviceModel: hardwareModel(),
            systemVersion: "\(device.systemName) \(device.systemVersion)",
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "1.0",
            appBuild: info?["CFBundleVersion"] as? String ?? "1"
        )
    }

    var body: String {
        String.localizedStringWithFormat(
            String(localized: "settings.support.body"),
            deviceModel,
            systemVersion,
            appVersion,
            appBuild
        )
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    private static func hardwareModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
