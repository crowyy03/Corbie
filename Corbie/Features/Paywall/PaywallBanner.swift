import CorbieCore
import SwiftUI

enum PaywallBannerState: Equatable {
    case trialEnding(daysLeft: Int)
    case readOnly(ReadOnlyCause)

    static func make(_ state: EntitlementState, cause: ReadOnlyCause?) -> PaywallBannerState? {
        switch state {
        case let .trial(daysLeft, _):
            return state.isTrialEndingSoon ? .trialEnding(daysLeft: daysLeft) : nil
        case .readOnly:
            return .readOnly(cause ?? .neverSubscribed)
        case .premium, .grace:
            return nil
        }
    }

    var daysLeft: Int? {
        switch self {
        case let .trialEnding(daysLeft): return daysLeft
        case .readOnly: return nil
        }
    }

    var reason: PaywallReason {
        switch self {
        case .trialEnding: return .trialEnding
        case .readOnly: return .readOnly
        }
    }

    var message: String {
        switch self {
        case .trialEnding:
            return PaywallCopy.text("paywall.banner.trial")
        case let .readOnly(cause):
            return PaywallCopy.text(PaywallBannerState.readOnlyKey(cause))
        }
    }

    var spokenMessage: String {
        switch self {
        case let .trialEnding(daysLeft):
            return String.localizedStringWithFormat(PaywallCopy.text("paywall.banner.trial.spoken"), daysLeft)
        case .readOnly:
            return message
        }
    }

    static func readOnlyKey(_ cause: ReadOnlyCause) -> String {
        switch cause {
        case .neverSubscribed: return "paywall.banner.readonly.never"
        case .subscriptionEnded: return "paywall.banner.readonly.ended"
        case .trialEnded: return "paywall.banner.readonly.trial"
        }
    }
}

struct PaywallBanner: View {
    @Environment(AppEnvironment.self) private var environment

    @ViewBuilder var body: some View {
        if let state = PaywallBannerState.make(environment.premiumGate.state, cause: environment.premiumGate.readOnlyCause) {
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
