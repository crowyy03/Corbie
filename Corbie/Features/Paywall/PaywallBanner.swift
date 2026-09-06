import CorbieCore
import SwiftUI

enum PaywallBannerState: Equatable {
    case trialEnding(daysLeft: Int)
    case readOnly

    static let noticeDays = PremiumGate.trialNoticeDays

    static func make(_ state: EntitlementState) -> PaywallBannerState? {
        switch state {
        case let .trial(daysLeft):
            return daysLeft <= noticeDays ? .trialEnding(daysLeft: daysLeft) : nil
        case .readOnly:
            return .readOnly
        case .active, .grace:
            return nil
        }
    }

    var daysLeft: Int {
        switch self {
        case let .trialEnding(daysLeft): return daysLeft
        case .readOnly: return 0
        }
    }

    var reason: PaywallReason {
        switch self {
        case .trialEnding: return .trialEnding
        case .readOnly: return .trialEnded
        }
    }

    var message: String {
        switch self {
        case .trialEnding:
            return PaywallCopy.text("paywall.banner.trial")
        case .readOnly:
            return PaywallCopy.text("paywall.banner.readonly")
        }
    }

    var spokenMessage: String {
        switch self {
        case let .trialEnding(daysLeft):
            return String.localizedStringWithFormat(PaywallCopy.text("paywall.banner.trial.spoken"), daysLeft)
        case .readOnly:
            return PaywallCopy.text("paywall.banner.readonly")
        }
    }
}

struct PaywallBanner: View {
    @Environment(AppEnvironment.self) private var environment

    @ViewBuilder var body: some View {
        if let state = PaywallBannerState.make(environment.premiumGate.state) {
            let actionTitle = String(localized: "paywall.banner.action")
            TrialBanner(
                daysLeft: state.daysLeft,
                message: state.message,
                actionTitle: actionTitle
            ) {
                environment.premiumGate.presentPaywall(reason: state.reason)
            }
            .padding(.horizontal, CorbieSpacing.m)
            .padding(.bottom, CorbieSpacing.xs)
            .accessibilityRepresentation {
                Button(state.spokenMessage) {
                    environment.premiumGate.presentPaywall(reason: state.reason)
                }
                .accessibilityHint(Text("paywall.banner.action"))
            }
        }
    }
}

private struct PaywallBannerInset: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            PaywallBanner()
        }
    }
}

extension View {
    func paywallBanner() -> some View {
        modifier(PaywallBannerInset())
    }
}
