import CorbieCore
import SwiftUI

extension WishPriority {
    var showsPill: Bool { self != .want }
}

struct WishPriorityPill: View {
    @Environment(\.palette) private var palette

    let priority: WishPriority

    var body: some View {
        Text(priority.title)
            .corbieSectionCaps()
            .foregroundStyle(palette.text2)
            .lineLimit(1)
            .padding(.horizontal, CorbieSpacing.xs)
            .padding(.vertical, CorbieSpacing.xxs)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline)
            )
    }
}

struct WishCardView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static let imageSide: CGFloat = 110
    static let markSide: CGFloat = 44
    private static let ownerDotRing: CGFloat = CorbieMetrics.hairline * 2
    private static let ownerDotSide: CGFloat = CorbieMetrics.memberDotSize + ownerDotRing * 2
    private static let ownerDotInset: CGFloat = CorbieRadius.card - ownerDotSide / 2

    static func stacksText(at size: DynamicTypeSize) -> Bool {
        size >= .xxxLarge
    }

    let wish: WishDTO
    let approximate: Money?
    let ownerSlot: MemberColorSlot?
    let ownerName: String

    private var money: Money? { WishPricing.money(for: wish) }

    private var stacksText: Bool { WishCardView.stacksText(at: dynamicTypeSize) }

    private var imageShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
    }

    private var layout: AnyLayout {
        stacksText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CorbieSpacing.m))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CorbieSpacing.m))
    }

    var body: some View {
        Card(padding: CorbieSpacing.l) {
            layout {
                photo
                details
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var photo: some View {
        WishPhoto(localImage: wish.localImage, imageURL: wish.imageURL, markSide: WishCardView.markSide)
            .frame(width: WishCardView.imageSide, height: WishCardView.imageSide)
            .clipShape(imageShape)
            .overlay(imageShape.strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline))
            .overlay(alignment: .bottomTrailing) {
                ownerDot
                    .padding(WishCardView.ownerDotInset)
            }
            .accessibilityHidden(true)
    }

    private var ownerDot: some View {
        MemberDot(slot: ownerSlot)
            .padding(WishCardView.ownerDotRing)
            .background(Circle().fill(palette.surface))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(wish.title)
                .corbieCardTitle()
                .foregroundStyle(palette.text)
                .lineLimit(stacksText ? 4 : 2)
                .multilineTextAlignment(.leading)
            price
            if wish.priority.showsPill {
                WishPriorityPill(priority: wish.priority)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var price: some View {
        if let money {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                    amount(money)
                    approximateText
                }
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    amount(money)
                    approximateText
                }
            }
        } else {
            Text("wishes.price.none")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
    }

    private func amount(_ money: Money) -> some View {
        Text(money.formatted())
            .corbieBody()
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(palette.text)
            .lineLimit(1)
    }

    @ViewBuilder private var approximateText: some View {
        if let approximate {
            Text(approximate.approximate())
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(1)
        }
    }

    private var accessibilityLabel: String {
        var parts = [wish.title, ownerName, money?.formatted() ?? String(localized: "wishes.price.none")]
        if let approximate { parts.append(approximate.approximate()) }
        if wish.priority.showsPill { parts.append(wish.priority.title) }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
private struct WishCardPreviewColumn: View {
    var body: some View {
        VStack(spacing: CorbieSpacing.m) {
            ForEach(WishPreviewState.allCases) { state in
                WishCardPreview(state: state)
            }
        }
    }
}

#Preview("Wish card") {
    PreviewThemes {
        WishCardPreviewColumn()
    }
}

#Preview("Wish card, xxxLarge") {
    PreviewThemes {
        WishCardPreviewColumn()
    }
    .dynamicTypeSize(.xxxLarge)
}
#endif
