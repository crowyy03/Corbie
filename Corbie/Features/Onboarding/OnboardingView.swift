import CorbieCore
import SwiftUI

struct OnboardingView: View {
    @Environment(\.palette) private var palette

    @State private var model: OnboardingViewModel
    private let environment: AppEnvironment
    private let appState: AppState
    private let joinCode: String?

    init(environment: AppEnvironment, appState: AppState, joinCode: String?) {
        self.environment = environment
        self.appState = appState
        self.joinCode = joinCode
        _model = State(initialValue: OnboardingViewModel(environment: environment, appState: appState))
    }

    var body: some View {
        ZStack {
            palette.bg
                .ignoresSafeArea()
            content
        }
        .animation(.easeInOut(duration: 0.2), value: model.step)
        .task { model.adopt(joinCode: joinCode) }
        .onChange(of: joinCode) { _, code in model.adopt(joinCode: code) }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .intro:
            OnboardingIntroView(model: model)
        case .profile:
            OnboardingProfileView(model: model)
        case .checkingICloud:
            checkingICloud
        case .invite:
            inviteStep
        case .join:
            joinStep
        }
    }

    @ViewBuilder private var inviteStep: some View {
        if let space = model.space {
            InviteView(
                environment: environment,
                appState: appState,
                spaceId: space.id,
                partner: model.storedPartner,
                onHasCode: { model.openJoin() },
                onDone: { Task { await model.finish() } }
            )
            .task { await model.followStoredPartner() }
        } else {
            ProgressView()
                .tint(palette.accent)
        }
    }

    private var checkingICloud: some View {
        VStack(spacing: CorbieSpacing.s) {
            ProgressView()
                .tint(palette.accent)
            Text("onboarding.invite.checking")
                .corbieMono()
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CorbieSpacing.l)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement(String(localized: "onboarding.invite.checking")).post()
        }
    }

    private var joinStep: some View {
        JoinView(
            environment: environment,
            appState: appState,
            localSpace: model.space,
            profile: model.profile,
            code: model.joinCode,
            onCancel: { Task { await model.cancelJoin() } }
        )
    }
}

#if DEBUG
#Preview {
    OnboardingView(environment: .preview(), appState: AppState(), joinCode: nil)
}
#endif
