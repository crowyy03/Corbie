import Foundation

public enum RemoteChangesMerged {
    public static let notificationName = Notification.Name(CorbieIdentifiers.bundleID + ".remote-changes-merged")

    static func post() {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}
