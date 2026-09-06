import CorbieCore
import SwiftUI

struct FreeTimePrivacySheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            Text("freetime.privacy.title")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)

            Text("freetime.privacy.body")
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: CorbieSpacing.l)

            VStack(spacing: CorbieSpacing.s) {
                PrimaryButton(title: String(localized: "freetime.sharing.toggle")) {
                    accept()
                }
                SecondaryButton(title: String(localized: "freetime.privacy.notnow")) {
                    decline()
                }
            }
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CorbieColorPalette.bg)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func accept() {
        BusyTimesPrivacyNotice.markSeen()
        Task {
            await BusyTimesSharing.set(true, in: environment)
            dismiss()
        }
    }

    private func decline() {
        BusyTimesPrivacyNotice.markSeen()
        dismiss()
    }
}

#if DEBUG
#Preview {
    FreeTimePrivacySheet()
        .environment(AppEnvironment.previewSignedIn())
}
#endif
