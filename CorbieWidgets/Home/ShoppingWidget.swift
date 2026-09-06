import CorbieCore
import SwiftUI
import WidgetKit

struct ShoppingEntry: TimelineEntry {
    let date: Date
    let snapshot: ShoppingSnapshot

    static let placeholder = ShoppingEntry(
        date: Date(),
        snapshot: ShoppingSnapshot(listId: nil, title: nil, items: [], remaining: 0, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> ShoppingEntry {
        let snapshot = (try? await provider.shopping(now: now))
            ?? ShoppingSnapshot(listId: nil, title: nil, items: [], remaining: 0, isPremium: true)
        return ShoppingEntry(date: now, snapshot: snapshot)
    }
}

struct ShoppingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.shopping,
            provider: CorbieTimelineProvider(placeholderEntry: ShoppingEntry.placeholder) { now in
                await ShoppingEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            ShoppingWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.shopping.title"))
        .description(Text("widget.shopping.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct ShoppingWidgetView: View {
    let entry: ShoppingEntry

    private var route: CorbieRoute {
        guard let listId = entry.snapshot.listId else { return .lists }
        return .list(listId)
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.items.isEmpty {
                WidgetEmptyState(title: "widget.shopping.empty", note: "widget.shopping.empty.note")
                    .widgetURL(route.url)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.snapshot.items) { item in
                        ShoppingRow(item: item)
                    }
                    if entry.snapshot.remaining > 0 {
                        WidgetOverflowLine(count: entry.snapshot.remaining)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(route.url)
            }
        }
    }
}

struct ShoppingRow: View {
    let item: WidgetShoppingItem

    private var markColor: Color {
        guard let colorKey = item.colorKey else { return CorbieColorPalette.text2 }
        return MemberColor(key: colorKey).color
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(intent: ToggleShoppingItemIntent(itemID: item.id)) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .corbieBody()
                    .imageScale(.large)
                    .foregroundStyle(markColor)
                    .frame(width: CorbieMetrics.minimumTapTarget, height: WidgetLayout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(String(format: String(localized: "widget.shopping.toggle.accessibility"), item.title))
            )
            .accessibilityValue(Text(item.isChecked ? "lists.item.checked" : "lists.item.unchecked"))
            Text(item.title)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .strikethrough(item.isChecked, color: CorbieColorPalette.text2)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
        }
        .frame(height: WidgetLayout.rowHeight)
    }
}

#if DEBUG
#Preview("Shopping", as: .systemMedium) {
    ShoppingWidget()
} timeline: {
    await ShoppingEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    ShoppingEntry(
        date: Date(),
        snapshot: ShoppingSnapshot(listId: UUID(), title: "Shopping", items: [], remaining: 0, isPremium: true)
    )
    ShoppingEntry(
        date: Date(),
        snapshot: ShoppingSnapshot(listId: nil, title: nil, items: [], remaining: 0, isPremium: false)
    )
}
#endif
