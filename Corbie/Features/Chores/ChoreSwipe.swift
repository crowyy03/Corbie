import CorbieCore
import CoreGraphics

enum ChoreSwipe {
    static let threshold: CGFloat = 80

    static func verdict(for translation: CGSize) -> ChoreVerdict? {
        if translation.height < -threshold, abs(translation.height) > abs(translation.width) {
            return .like
        }
        guard abs(translation.width) > threshold else { return nil }
        return translation.width < 0 ? .hate : .fine
    }
}
