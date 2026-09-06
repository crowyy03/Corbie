import CorbieCore
import SwiftUI
import UIKit

struct SettingsNotificationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = SettingsNotificationsViewModel()

    var body: some View {
        List {
            Section {
                permissionRow
            } header: {
                SectionCaps(text: String(localized: "settings.notifications.permission.header"))
            }
            .listRowBackground(CorbieColorPalette.surface)

            Section {
                ForEach(SettingsNotificationToggle.allCases) { toggle in
                    row(toggle)
                }
            } header: {
                SectionCaps(text: String(localized: "settings.notifications.types.header"))
            } footer: {
                Text("settings.notifications.footer")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
            .listRowBackground(CorbieColorPalette.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "settings.notifications.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(environment) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.refreshAuthorization() }
        }
    }

    private func row(_ toggle: SettingsNotificationToggle) -> some View {
        Toggle(isOn: binding(for: toggle)) {
            Text(String(localized: String.LocalizationValue(toggle.titleKey)))
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
        }
        .tint(CorbieColorPalette.ice)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private func binding(for toggle: SettingsNotificationToggle) -> Binding<Bool> {
        Binding(
            get: { model.binding(for: toggle) },
            set: { isOn in Task { await model.set(toggle, isOn: isOn) } }
        )
    }

    @ViewBuilder private var permissionRow: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(statusKey)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
            Text("settings.notifications.permission.note")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            if model.isDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button(String(localized: "settings.notifications.permission.open")) {
                    openURL(url)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CorbieColorPalette.ice)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
        }
        .padding(.vertical, CorbieSpacing.xxs)
        .accessibilityElement(children: .contain)
    }

    private var statusKey: LocalizedStringKey {
        switch model.authorization {
        case .authorized: return "settings.notifications.permission.allowed"
        case .provisional: return "settings.notifications.permission.quiet"
        case .denied: return "settings.notifications.permission.denied"
        case .notDetermined: return "settings.notifications.permission.notasked"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsNotificationsView()
    }
    .environment(AppEnvironment.previewSignedIn())
}
