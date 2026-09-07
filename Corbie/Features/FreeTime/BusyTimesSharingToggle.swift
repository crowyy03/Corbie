import CorbieCore
import SwiftUI

struct BusyTimesSharingToggle: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Toggle(isOn: sharing) {
                Text("freetime.sharing.toggle")
                    .corbieBody()
                    .foregroundStyle(palette.text)
            }
            .tint(palette.accent)
            .disabled(isSaving)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)

            Text("freetime.sharing.hint")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .padding(.vertical, CorbieSpacing.xxs)
    }

    private var sharing: Binding<Bool> {
        Binding(
            get: { environment.currentMember?.sharesBusyTimes ?? false },
            set: { isOn in
                isSaving = true
                Task {
                    await BusyTimesSharing.set(isOn, in: environment)
                    isSaving = false
                }
            }
        )
    }
}

#if DEBUG
#Preview {
    BusyTimesSharingToggle()
        .padding(CorbieSpacing.l)
        .background(CorbieTheme.sand.palette.bg)
        .environment(AppEnvironment.previewSignedIn())
}
#endif
