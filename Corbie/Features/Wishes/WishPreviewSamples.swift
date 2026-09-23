#if DEBUG
import CorbieCore
import SwiftUI
import UIKit

enum WishPreviewState: String, CaseIterable, Identifiable {
    case photo
    case nophoto
    case noprice
    case longtitle

    var id: String { rawValue }
}

enum WishPreviewSamples {
    static let screen = CGSize(width: 393, height: 852)
    static let ownerSlot = MemberColorSlot.creatorDefault
    static let createdAt = Date(timeIntervalSince1970: 1_788_523_200)

    static var ownerName: String { String(localized: "member.name.you") }

    static func wish(_ state: WishPreviewState, palette: ThemePalette) -> WishDTO {
        switch state {
        case .photo:
            return WishDTO(
                id: UUID(),
                title: "Linen apron",
                url: "https://www.etsy.com/listing/1184/linen-apron",
                localImage: photo(palette),
                price: 48,
                currency: "USD",
                priority: .must,
                source: .etsy,
                createdAt: createdAt
            )
        case .nophoto:
            return WishDTO(
                id: UUID(),
                title: "Chemex filters",
                url: "https://www.chemexcoffeemaker.com/bonded-filters",
                price: 12.5,
                currency: "USD",
                priority: .someday,
                source: .store,
                createdAt: createdAt
            )
        case .noprice:
            return WishDTO(
                id: UUID(),
                title: "Ceramic vase",
                localImage: lightPhoto(),
                note: "the tall one, sand glaze",
                createdAt: createdAt
            )
        case .longtitle:
            return WishDTO(
                id: UUID(),
                title: "Handmade natural linen apron with two deep pockets and adjustable cross-back straps",
                url: "https://www.example-shop.com/collections/kitchen/products/natural-linen-apron-cross-back-straps",
                localImage: darkBusyPhoto(),
                price: 1249,
                currency: "EUR",
                priority: .must,
                source: .store,
                createdAt: createdAt
            )
        }
    }

    static func approximate(_ state: WishPreviewState) -> Money? {
        switch state {
        case .photo: return Money(amount: Decimal(44), currency: "EUR")
        case .longtitle: return Money(amount: Decimal(1360), currency: "USD")
        case .nophoto, .noprice: return nil
        }
    }

    static func photo(_ palette: ThemePalette) -> Data {
        drawn { context, side in
            UIColor(palette.accent).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor(palette.surface).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: side * 0.2, y: side * 0.14, width: side * 0.6, height: side * 0.6))
            UIColor(palette.border).setFill()
            context.fill(CGRect(x: 0, y: side * 0.72, width: side, height: side * 0.28))
            UIColor(palette.text).withAlphaComponent(0.7).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: side * 0.38, y: side * 0.5, width: side * 0.24, height: side * 0.3))
        }
    }

    static func lightPhoto() -> Data {
        let light = CorbieTheme.sand.palette
        return drawn { context, side in
            UIColor(CorbieTheme.ice.palette.surface).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor(light.bg).setFill()
            context.fill(CGRect(x: 0, y: side * 0.7, width: side, height: side * 0.3))
            UIColor(light.elevated).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: side * 0.26, y: side * 0.7, width: side * 0.48, height: side * 0.08))
            UIColor(light.border).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: side * 0.32, y: side * 0.3, width: side * 0.36, height: side * 0.44))
            context.fill(CGRect(x: side * 0.43, y: side * 0.16, width: side * 0.14, height: side * 0.2))
        }
    }

    static func darkBusyPhoto() -> Data {
        let dark = CorbieTheme.deep.palette
        let light = CorbieTheme.sand.palette
        return drawn { context, side in
            UIColor(dark.bg).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let cell = side / 12
            for row in 0 ..< 6 {
                for column in 0 ..< 12 {
                    UIColor((row + column).isMultiple(of: 2) ? light.border : dark.surface).setFill()
                    context.fill(CGRect(x: CGFloat(column) * cell, y: side / 2 + CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            UIColor(light.accent).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: side * 0.3, y: side * 0.12, width: side * 0.4, height: side * 0.56),
                cornerRadius: side * 0.06
            ).fill()
            UIColor(dark.text2).setFill()
            context.fill(CGRect(x: side * 0.36, y: side * 0.4, width: side * 0.28, height: side * 0.12))
        }
    }

    private static func drawn(_ draw: (UIGraphicsImageRendererContext, CGFloat) -> Void) -> Data {
        let side: CGFloat = 480
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            draw(context, side)
        }
        return image.pngData() ?? Data()
    }
}

struct WishCardPreview: View {
    @Environment(\.palette) private var palette

    let state: WishPreviewState

    var body: some View {
        WishCardView(
            wish: WishPreviewSamples.wish(state, palette: palette),
            approximate: WishPreviewSamples.approximate(state),
            ownerSlot: WishPreviewSamples.ownerSlot,
            ownerName: WishPreviewSamples.ownerName
        )
    }
}

struct WishDetailStill: View {
    @Environment(\.palette) private var palette

    let state: WishPreviewState

    var body: some View {
        let wish = WishPreviewSamples.wish(state, palette: palette)
        WishDetailLayout(wish: wish, actions: WishDetailActions()) { heroHeight in
            WishDetailColumn(
                wish: wish,
                approximate: WishPreviewSamples.approximate(state),
                ownerSlot: WishPreviewSamples.ownerSlot,
                addedLine: WishDetailText.added(
                    ownerName: WishPreviewSamples.ownerName,
                    createdAt: wish.createdAt,
                    now: WishPreviewSamples.createdAt
                ),
                heroHeight: heroHeight,
                openLink: { _ in }
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .coordinateSpace(.named(WishDetailMetrics.scrollSpace))
        }
        .clipped()
    }
}

struct WishDetailPreview: View {
    let state: WishPreviewState

    var body: some View {
        WishDetailStill(state: state)
            .frame(height: WishPreviewSamples.screen.height)
            .clipShape(RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous))
    }
}
#endif
