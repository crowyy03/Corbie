import Foundation

public enum WidgetReloadRequest {
    public static let notificationName = Notification.Name(CorbieIdentifiers.bundleID + ".widget-reload")

    public static func post() {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}
