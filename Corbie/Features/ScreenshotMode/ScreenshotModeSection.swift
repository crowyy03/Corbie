#if DEBUG
import CorbieCore
import SwiftUI

struct ScreenshotModeSection: View {
    @Environment(\.palette) private var palette
    @Environment(ScreenshotModeSwitch.self) private var screenshotMode: ScreenshotModeSwitch?

    var body: some View {
        if let screenshotMode {
            Section {
                if screenshotMode.isOn {
                    row("Leave screenshot mode") { await screenshotMode.leave() }
                } else {
                    row("Enter screenshot mode") { await screenshotMode.enter() }
                }
            } header: {
                Text(verbatim: "Screenshot mode")
            } footer: {
                Text(verbatim: footer(screenshotMode))
            }
            .listRowBackground(palette.surface)
        }
    }

    private func row(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(verbatim: title)
                .corbieBody()
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
    }

    private func footer(_ screenshotMode: ScreenshotModeSwitch) -> String {
        guard screenshotMode.isOn else {
            return "Opens \(ScreenshotModeDemo.meName) and \(ScreenshotModeDemo.partnerName) on a separate local store "
                + "with nothing synced. Your space stays as it is."
        }
        let session = screenshotMode.sessionId ?? "-"
        return "Demo data on a local store, nothing leaves the device. Leaving brings your space back.\nsession \(session)"
    }
}
#endif
