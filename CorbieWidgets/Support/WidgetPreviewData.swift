#if DEBUG
import CorbieCore
import Foundation

enum WidgetPreviewData {
    static func provider(now: Date = Date()) async -> WidgetDataProvider {
        WidgetDataProvider(controller: await PersistenceController.previewSeeded(now: now))
    }
}
#endif
