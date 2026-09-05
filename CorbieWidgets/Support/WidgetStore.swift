import CorbieCore
import Foundation
import WidgetKit

enum WidgetStore {
    static func provider() -> WidgetDataProvider {
        WidgetDataProvider(
            controller: IntentPersistence.shared.controller(),
            identity: IntentPersistence.shared.identity()
        )
    }
}

enum WidgetTimelineBuilder {
    static func timeline<Entry: TimelineEntry>(
        now: Date = Date(),
        load: (Date) async -> Entry
    ) async -> Timeline<Entry> {
        let midnight = WidgetTimelineDates.nextMidnight(after: now)
        let entries = [await load(now), await load(midnight)]
        return Timeline(entries: entries, policy: .after(midnight))
    }
}

struct CorbieTimelineProvider<Entry: TimelineEntry>: TimelineProvider {
    let placeholderEntry: Entry
    let load: (Date) async -> Entry

    func placeholder(in context: Context) -> Entry {
        placeholderEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        Task {
            completion(await load(Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            completion(await WidgetTimelineBuilder.timeline(load: load))
        }
    }
}
