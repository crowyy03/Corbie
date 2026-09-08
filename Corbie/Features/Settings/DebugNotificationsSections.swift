#if DEBUG
import CorbieCore
import SwiftUI

struct DebugNotificationsSections: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @State private var authorization: NotificationAuthorization = .notDetermined
    @State private var pending: [String] = []
    @State private var hasSeenJointAction = false

    var body: some View {
        Group {
            Section {
                line(title: "Notification permission", value: authorization.rawValue)
                line(title: "Joint action seen", value: hasSeenJointAction.description)
                line(title: "Entitlement", value: String(describing: environment.premiumGate.state))
                line(title: "Space", value: environment.space?.id.uuidString ?? "-")
                line(title: "Member", value: environment.currentMember?.id.uuidString ?? "-")
            } header: {
                Text(verbatim: "State")
            }
            .listRowBackground(palette.surface)

            Section {
                if pending.isEmpty {
                    Text(verbatim: "none")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
                ForEach(pending, id: \.self) { identifier in
                    Text(verbatim: identifier)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            } header: {
                Text(verbatim: "Pending notifications")
            }
            .listRowBackground(palette.surface)

            Section {
                Button {
                    Task {
                        await environment.remoteChanges.forgetJointAction()
                        await reload()
                    }
                } label: {
                    Text(verbatim: "Forget the joint action flag")
                        .corbieBody()
                        .foregroundStyle(palette.accent)
                }
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
            .listRowBackground(palette.surface)
        }
        .task { await reload() }
    }

    private func line(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(verbatim: title)
                .corbieBody()
                .foregroundStyle(palette.text)
            Text(verbatim: value)
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .padding(.vertical, CorbieSpacing.xxs)
    }

    private func reload() async {
        authorization = await environment.notifications.authorizationStatus()
        pending = await environment.notifications.pendingIdentifiers().sorted()
        hasSeenJointAction = await environment.remoteChanges.hasSeenJointAction
    }
}

#Preview {
    NavigationStack {
        List {
            DebugNotificationsSections()
        }
    }
    .environment(AppEnvironment.previewSignedIn())
}
#endif
