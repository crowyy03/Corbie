import CorbieCore
import SwiftUI
import WidgetKit

struct PartnerWishesEntry: TimelineEntry {
    let date: Date
    let snapshot: PartnerWishesSnapshot

    static let placeholder = PartnerWishesEntry(
        date: Date(),
        snapshot: PartnerWishesSnapshot(items: [], remaining: 0, partnerName: nil, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> PartnerWishesEntry {
        let snapshot = (try? await provider.partnerWishes(now: now))
            ?? PartnerWishesSnapshot(items: [], remaining: 0, partnerName: nil, isPremium: true)
        return PartnerWishesEntry(date: now, snapshot: snapshot)
    }
}

struct PartnerWishesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.partnerWishes,
            provider: CorbieTimelineProvider(placeholderEntry: PartnerWishesEntry.placeholder) { now in
                await PartnerWishesEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            PartnerWishesWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.wishes.title"))
        .description(Text("widget.wishes.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct PartnerWishesWidgetView: View {
    let entry: PartnerWishesEntry

    private var heading: String {
        guard let name = entry.snapshot.partnerName, name.isEmpty == false else {
            return String(localized: "widget.wishes.heading.plain")
        }
        return String(format: String(localized: "widget.wishes.heading"), name)
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.items.isEmpty {
                WidgetEmptyState(title: "widget.wishes.empty", note: "widget.wishes.empty.note")
                    .widgetURL(CorbieRoute.wishes.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    WidgetHeading(text: heading)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entry.snapshot.items) { wish in
                            WishRow(wish: wish)
                        }
                    }
                    if entry.snapshot.remaining > 0 {
                        WidgetOverflowLine(count: entry.snapshot.remaining)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.wishes.url)
            }
        }
    }
}

struct WishRow: View {
    @Environment(\.palette) private var palette

    let wish: WidgetWish

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Text(wish.title)
                .corbieBody()
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
            if let priceText = wish.priceText {
                Text(priceText)
                    .corbieMono()
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
            }
        }
        .frame(height: WidgetLayout.wishRowHeight)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Partner wishes", as: .systemMedium) {
    PartnerWishesWidget()
} timeline: {
    await PartnerWishesEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    PartnerWishesEntry(
        date: Date(),
        snapshot: PartnerWishesSnapshot(items: [], remaining: 0, partnerName: "Sofia", isPremium: true)
    )
    PartnerWishesEntry(
        date: Date(),
        snapshot: PartnerWishesSnapshot(items: [], remaining: 0, partnerName: nil, isPremium: false)
    )
}
#endif
