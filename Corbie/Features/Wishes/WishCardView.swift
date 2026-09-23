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

    let wish: WishDTO
    let approximate: Money?
    let ownerSlot: MemberColorSlot?
    let ownerName: String

    private var money: Money? { WishPricing.money(for: wish) }

    private var stacksText: Bool { dynamicTypeSize.isAccessibilitySize }

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
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            HStack(alignment: .top, spacing: CorbieSpacing.xs) {
                ownerDotOnFirstLine
                Text(wish.title)
                    .corbieCardTitle()
                    .foregroundStyle(palette.text)
                    .lineLimit(stacksText ? 4 : 2)
                    .multilineTextAlignment(.leading)
            }
            price
            if wish.priority.showsPill {
                WishPriorityPill(priority: wish.priority)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ownerDotOnFirstLine: some View {
        Text(verbatim: " ")
            .corbieCardTitle()
            .hidden()
            .frame(width: CorbieMetrics.memberDotSize)
            .overlay { MemberDot(slot: ownerSlot) }
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
#Preview("Wish card") {
    PreviewThemes {
        VStack(spacing: CorbieSpacing.m) {
            ForEach(WishPreviewState.allCases) { state in
                WishCardPreview(state: state)
            }
        }
    }
}
#endif
