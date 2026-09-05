import CorbieCore
import SwiftUI

struct JoinView: View {
    @State private var model: JoinViewModel
    private let onCancel: () -> Void
    private let onJoined: () -> Void

    init(
        environment: AppEnvironment,
        appState: AppState,
        localSpace: SpaceDTO?,
        profile: ProfileDraft,
        code: String?,
        onCancel: @escaping () -> Void,
        onJoined: @escaping () -> Void = {}
    ) {
        _model = State(
            initialValue: JoinViewModel(
                environment: environment,
                appState: appState,
                localSpace: localSpace,
                profile: profile,
                code: code
            )
        )
        self.onCancel = onCancel
        self.onJoined = onJoined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            Text("pairing.join.title")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)

            TextFieldRow(
                label: String(localized: "pairing.join.field.label"),
                placeholder: String(localized: "pairing.join.field.placeholder"),
                hint: String(localized: "pairing.join.field.hint"),
                text: $model.code
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .disabled(model.isWorking)
            .onChange(of: model.code) { _, _ in model.normalizeCode() }

            if let message = model.block?.message ?? model.failure {
                Text(verbatim: message)
                    .corbieCaption()
                    .foregroundStyle(CorbieColorPalette.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.isWorking {
                HStack(spacing: CorbieSpacing.s) {
                    ProgressView()
                        .tint(CorbieColorPalette.ice)
                    Text("pairing.join.working")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }

            Spacer()

            PrimaryButton(title: String(localized: "pairing.join.submit")) {
                Task { await model.submit() }
            }
            .disabled(model.canSubmit == false)

            SecondaryButton(title: String(localized: "pairing.join.later"), action: onCancel)
                .disabled(model.isWorking)
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CorbieColorPalette.bg)
        .onChange(of: model.phase) { _, phase in
            guard phase == .joined else { return }
            onJoined()
        }
    }
}

struct JoinSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let code: String?

    var body: some View {
        NavigationStack {
            JoinView(
                environment: environment,
                appState: appState,
                localSpace: environment.space,
                profile: ProfileDraft.from(
                    member: environment.currentMember,
                    space: environment.space,
                    appleName: nil
                ),
                code: code,
                onCancel: { dismiss() },
                onJoined: { dismiss() }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.action.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    JoinView(
        environment: .preview(),
        appState: AppState(),
        localSpace: nil,
        profile: ProfileDraft(),
        code: nil,
        onCancel: {}
    )
}
