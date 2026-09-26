import Foundation

public enum CloudKitEnvironment: String, Sendable, Equatable, CaseIterable, Codable {
    case development
    case production

    public static let infoKey = "CorbieCloudKitEnvironment"

    public init?(declaration: String?) {
        guard let declaration else { return nil }
        self.init(rawValue: declaration.lowercased())
    }

    public static func declared(in bundle: Bundle = .main) -> CloudKitEnvironment? {
        CloudKitEnvironment(declaration: bundle.object(forInfoDictionaryKey: infoKey) as? String)
    }
}
