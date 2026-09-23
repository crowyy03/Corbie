import CorbieCore
import SwiftUI

enum WishDetailMetrics {
    static let heroShareOfScreen: CGFloat = 0.4
    static let heroMarkSide: CGFloat = 96
    static let scrollSpace = "wish.detail.scroll"

    static func heroHeight(screenHeight: CGFloat) -> CGFloat {
        (screenHeight * heroShareOfScreen).rounded()
    }

    static func heroStretch(height: CGFloat, pull: CGFloat) -> CGFloat {
        guard height > 0, pull > 0 else { return 1 }
        return (height + pull) / height
    }
}

struct WishDetailActions {
    var back: () -> Void = {}
    var edit: () -> Void = {}
    var delete: () -> Void = {}
    var open: (URL) -> Void = { _ in }
    var fulfil: () -> Void = {}
}

struct WishDetailContent: View {
    let wish: WishDTO
    let approximate: Money?
    let ownerSlot: MemberColorSlot?
    let addedLine: String
    let actions: WishDetailActions

    var body: some View {
        WishDetailLayout(wish: wish, actions: actions) { heroHeight in
            ScrollView {
                WishDetailColumn(
                    wish: wish,
                    approximate: approximate,
                    ownerSlot: ownerSlot,
                    addedLine: addedLine,
                    heroHeight: heroHeight,
                    openLink: actions.open
                )
            }
            .coordinateSpace(.named(WishDetailMetrics.scrollSpace))
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct WishDetailLayout<Column: View>: View {
    @Environment(\.palette) private var palette

    let wish: WishDTO
    let actions: WishDetailActions
    @ViewBuilder let column: (CGFloat) -> Column

    var body: some View {
        GeometryReader { proxy in
            column(
                WishDetailMetrics.heroHeight(
                    screenHeight: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                )
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WishDetailActionBar(
                link: WishDetailText.pageURL(of: wish),
                isFulfilled: wish.isFulfilled,
                open: actions.open,
                fulfil: actions.fulfil
            )
        }
        .overlay(alignment: .top) {
            WishDetailChrome(back: actions.back, edit: actions.edit, delete: actions.delete)
                .accessibilitySortPriority(1)
        }
        .accessibilityElement(children: .contain)
        .background(palette.bg.ignoresSafeArea())
    }
}

struct WishDetailColumn: View {
    @Environment(\.palette) private var palette

    let wish: WishDTO
    let approximate: Money?
    let ownerSlot: MemberColorSlot?
    let addedLine: String
    let heroHeight: CGFloat
    let openLink: (URL) -> Void

    private var money: Money? { WishPricing.money(for: wish) }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: CorbieRadius.card,
            topTrailingRadius: CorbieRadius.card,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            sheet
                .padding(.top, -CorbieRadius.card)
        }
    }

    private var hero: some View {
        WishPhoto(localImage: wish.localImage, imageURL: wish.imageURL, markSide: WishDetailMetrics.heroMarkSide)
            .frame(height: heroHeight)
            .visualEffect { content, proxy in
                content.scaleEffect(
                    WishDetailMetrics.heroStretch(
                        height: proxy.size.height,
                        pull: proxy.frame(in: .named(WishDetailMetrics.scrollSpace)).minY
                    ),
                    anchor: .bottom
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(wish.title)
            .accessibilityAddTraits(.isImage)
            .accessibilityHidden(WishPhoto.hasSource(localImage: wish.localImage, imageURL: wish.imageURL) == false)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                HStack(spacing: CorbieSpacing.xs) {
                    MemberDot(slot: ownerSlot)
                    Text(addedLine)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
                Text(wish.title)
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            priceRow
            if let link = WishDetailText.pageURL(of: wish) {
                linkRow(link)
            }
            if let note = wish.note, note.isEmpty == false {
                FieldRow(label: String(localized: "wishes.editor.note")) {
                    Text(note)
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.top, CorbieSpacing.xl)
        .padding(.bottom, CorbieSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bg, in: sheetShape)
    }

    private var priceRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: CorbieSpacing.s) {
                priceText
                pill
            }
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                priceText
                pill
            }
        }
    }

    @ViewBuilder private var priceText: some View {
        if let money {
            HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                Text(money.formatted())
                    .corbieIntroTitle()
                    .monospacedDigit()
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if let approximate {
                    Text(approximate.approximate())
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .lineLimit(1)
                }
            }
        } else {
            Text("wishes.price.none")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
    }

    @ViewBuilder private var pill: some View {
        if wish.priority.showsPill {
            WishPriorityPill(priority: wish.priority)
        }
    }

    private func linkRow(_ link: URL) -> some View {
        let shape = RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
        return Button {
            openLink(link)
        } label: {
            HStack(spacing: CorbieSpacing.s) {
                Text(verbatim: WishDetailText.link(link))
                    .corbieMono()
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, CorbieSpacing.m)
            .padding(.vertical, CorbieSpacing.s)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .background(palette.elevated, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}

struct WishDetailActionBar: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let link: URL?
    let isFulfilled: Bool
    let open: (URL) -> Void
    let fulfil: () -> Void

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: CorbieSpacing.s))
            : AnyLayout(LeadingTwoThirdsLayout(spacing: CorbieSpacing.s))
    }

    var body: some View {
        Group {
            if let link {
                layout {
                    PrimaryButton(title: String(localized: "wishes.detail.open")) {
                        open(link)
                    }
                    fulfilButton
                }
            } else {
                fulfilButton
            }
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.s)
        .background(palette.bg)
    }

    @ViewBuilder private var fulfilButton: some View {
        if isFulfilled {
            SecondaryButton(title: String(localized: "wishes.detail.fulfilled"), systemImage: "checkmark") {}
                .disabled(true)
                .accessibilityAddTraits(.isSelected)
        } else {
            SecondaryButton(title: String(localized: "wishes.detail.fulfilled"), action: fulfil)
                .accessibilityHint(Text("wishes.action.gifted"))
        }
    }
}

struct WishDetailChrome: View {
    let back: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                WishChromeGlyph(systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("common.action.back"))
            Spacer(minLength: 0)
            Menu {
                Button(String(localized: "common.action.edit"), action: edit)
                Button(String(localized: "common.action.delete"), role: .destructive, action: delete)
            } label: {
                WishChromeGlyph(systemImage: "ellipsis")
            }
            .accessibilityLabel(Text("wishes.detail.menu"))
        }
        .padding(.horizontal, CorbieSpacing.m)
        .padding(.top, CorbieSpacing.xs)
    }
}

private struct WishChromeGlyph: View {
    @Environment(\.palette) private var palette

    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .corbieBody()
            .fontWeight(.semibold)
            .foregroundStyle(palette.text)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
            .background(.ultraThinMaterial, in: Circle())
            .contentShape(Circle())
    }
}

struct LeadingTwoThirdsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let height = zip(subviews, widths(total: width, count: subviews.count))
            .map { subview, columnWidth in
                subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, columnWidth) in zip(subviews, widths(total: bounds.width, count: subviews.count)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: bounds.height)
            )
            x += columnWidth + spacing
        }
    }

    private func widths(total: CGFloat, count: Int) -> [CGFloat] {
        guard count > 1 else { return [total] }
        let available = max(0, total - spacing * CGFloat(count - 1))
        let leading = available * 2 / 3
        let rest = (available - leading) / CGFloat(count - 1)
        return [leading] + Array(repeating: rest, count: count - 1)
    }
}

#if DEBUG
#Preview("Wish detail - with photo") {
    PreviewThemes {
        WishDetailPreview(state: .photo)
    }
}

#Preview("Wish detail - without photo") {
    PreviewThemes {
        WishDetailPreview(state: .nophoto)
    }
}

#Preview("Wish detail - without price") {
    PreviewThemes {
        WishDetailPreview(state: .noprice)
    }
}

#Preview("Wish detail - long title") {
    PreviewThemes {
        WishDetailPreview(state: .longtitle)
    }
}
#endif
