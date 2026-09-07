import CorbieCore
import SwiftUI
import UIKit

struct WishThumbnail: View {
    @Environment(\.palette) private var palette

    static let side: CGFloat = 64

    let localImage: Data?
    let imageURL: String?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
    }

    var body: some View {
        shape
            .fill(palette.elevated)
            .overlay {
                if let localImage, let image = UIImage(data: localImage) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let link = imageURL, let url = URL(string: link) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        fallback
                    }
                } else {
                    fallback
                }
            }
            .frame(width: WishThumbnail.side, height: WishThumbnail.side)
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline))
            .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image(systemName: "link")
            .font(.system(size: CorbieSpacing.l, weight: .light))
            .foregroundStyle(palette.text2)
    }
}

struct WishPriorityBadge: View {
    @Environment(\.palette) private var palette

    let priority: WishPriority

    private var isTinted: Bool { priority == .must }

    var body: some View {
        Text(priority.title)
            .corbieSectionCaps()
            .foregroundStyle(isTinted ? palette.ctaText : palette.text2)
            .padding(.horizontal, CorbieSpacing.xs)
            .padding(.vertical, CorbieSpacing.xxs)
            .background(
                Capsule(style: .continuous)
                    .fill(isTinted ? palette.accent : palette.elevated)
            )
    }
}

struct WishCardView: View {
    @Environment(\.palette) private var palette

    let wish: WishDTO
    let approximate: Money?
    let ownerSlot: MemberColorSlot?
    let ownerName: String

    private var money: Money? { WishPricing.money(for: wish) }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                WishThumbnail(localImage: wish.localImage, imageURL: wish.imageURL)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(spacing: CorbieSpacing.xs) {
                        MemberDot(slot: ownerSlot)
                        Text(wish.title)
                            .corbieBody()
                            .foregroundStyle(palette.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if let money {
                        priceRow(money)
                    }
                    footer
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func priceRow(_ money: Money) -> some View {
        HStack(spacing: CorbieSpacing.xs) {
            Text(money.formatted())
                .corbieBody()
                .foregroundStyle(palette.text)
            if let approximate {
                Text(approximate.approximate())
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
        }
        .lineLimit(1)
    }

    private var footer: some View {
        HStack(spacing: CorbieSpacing.xs) {
            WishPriorityBadge(priority: wish.priority)
            if let tag = wish.source.tag(url: wish.url) {
                Text(tag)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
        }
        .padding(.top, CorbieSpacing.xxs)
    }

    private var accessibilityLabel: String {
        var parts = [ownerName, wish.title, wish.priority.title]
        if let money { parts.append(money.formatted()) }
        if let approximate { parts.append(approximate.approximate()) }
        if let tag = wish.source.tag(url: wish.url) { parts.append(tag) }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: CorbieSpacing.m) {
        WishCardView(
            wish: WishDTO(
                id: UUID(),
                title: "Linen apron",
                url: "https://www.etsy.com/listing/1",
                price: 48,
                currency: "USD",
                priority: .must,
                source: .etsy
            ),
            approximate: Money(amount: Decimal(44), currency: "EUR"),
            ownerSlot: MemberColorSlot.rose,
            ownerName: "Sofia"
        )
        WishCardView(
            wish: WishDTO(id: UUID(), title: "Chemex filters", priority: .someday, source: .manual),
            approximate: nil,
            ownerSlot: MemberColorSlot.teal,
            ownerName: "you"
        )
    }
    .padding(CorbieSpacing.m)
    .frame(maxHeight: .infinity)
    .background(CorbieTheme.sand.palette.bg)
}
#endif
