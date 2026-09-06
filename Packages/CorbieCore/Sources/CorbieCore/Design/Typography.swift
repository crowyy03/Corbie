import SwiftUI

public enum CorbieFont {
    public static let screenTitleSize: CGFloat = 34
    public static let sectionCapsSize: CGFloat = 12
    public static let bodySize: CGFloat = 17
    public static let captionSize: CGFloat = 13
    public static let monoSize: CGFloat = 13
    public static let counterSize: CGFloat = 56

    public static let screenTitleTracking: CGFloat = -0.4
    public static let sectionCapsTracking: CGFloat = 1.2
}

struct CorbieScreenTitleStyle: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = CorbieFont.screenTitleSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold, design: .default))
            .tracking(CorbieFont.screenTitleTracking)
    }
}

struct CorbieSectionCapsStyle: ViewModifier {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = CorbieFont.sectionCapsSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .tracking(CorbieFont.sectionCapsTracking)
            .textCase(.uppercase)
    }
}

struct CorbieBodyStyle: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = CorbieFont.bodySize

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .regular, design: .default))
    }
}

struct CorbieCaptionStyle: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = CorbieFont.captionSize

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .regular, design: .default))
    }
}

struct CorbieMonoStyle: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = CorbieFont.monoSize

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .regular, design: .monospaced))
    }
}

struct CorbieCounterStyle: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = CorbieFont.counterSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .heavy, design: .rounded).monospacedDigit())
            .tracking(CorbieFont.screenTitleTracking)
    }
}

public extension View {
    func corbieScreenTitle() -> some View {
        modifier(CorbieScreenTitleStyle())
    }

    func corbieSectionCaps() -> some View {
        modifier(CorbieSectionCapsStyle())
    }

    func corbieBody() -> some View {
        modifier(CorbieBodyStyle())
    }

    func corbieCaption() -> some View {
        modifier(CorbieCaptionStyle())
    }

    func corbieMono() -> some View {
        modifier(CorbieMonoStyle())
    }

    func corbieCounter() -> some View {
        modifier(CorbieCounterStyle())
    }
}
