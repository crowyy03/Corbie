import CorbieCore
import SwiftUI

struct PaywallView: View {
    let request: PaywallRequest
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: CorbieSpacing.l) {
                Text("paywall.headline")
                    .corbieScreenTitle()
                    .foregroundStyle(CorbieColorPalette.text)
                    .multilineTextAlignment(.center)
                Text("paywall.placeholder.note")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(CorbieSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CorbieColorPalette.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.action.done")) {
                        environment.premiumGate.dismissPaywall()
                        dismiss()
                    }
                }
            }
        }
    }
}
