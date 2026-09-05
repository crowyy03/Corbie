import Foundation

public protocol SecretStore: Sendable {
    func data(for key: String) throws -> Data?
    func setData(_ value: Data, for key: String) throws
    func removeValue(for key: String) throws
}

extension SecretStore {
    public func string(for key: String) throws -> String? {
        guard let data = try data(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw CorbieError.invalidInput("value for \(key) is not utf8")
        }
        try setData(data, for: key)
    }
}
