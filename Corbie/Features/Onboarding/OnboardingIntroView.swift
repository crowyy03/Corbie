import AuthenticationServices
import CorbieCore
import SwiftUI

struct OnboardingIntroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: OnboardingViewModel

    private let dotSize: CGFloat = 8

    var body: some View {
        VStack(spacing: CorbieSpacing.l) {
            TabView(selection: $model.page) {
                markPage.tag(0)
                cardsPage.tag(1)
                soloPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
            signInButton

            Text("onboarding.intro.signin.note")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.bottom, CorbieSpacing.l)
        .onAppear { model.recordStep(model.page) }
        .onChange(of: model.page) { _, page in model.recordStep(page) }
    }

    private var markPage: some View {
        VStack(spacing: CorbieSpacing.l) {
            Spacer()
            CorbieMarkView(size: 76)
            Text("onboarding.intro.page1.title")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
                .multilineTextAlignment(.center)
            Text("onboarding.intro.page1.note")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var cardsPage: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            Spacer()
            Text("onboarding.intro.page2.title")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
            featureCard(
                systemImage: "checkmark.circle",
                title: Text("onboarding.intro.tasks.title"),
                note: Text("onboarding.intro.tasks.note")
            )
            featureCard(
                systemImage: "star",
                title: Text("onboarding.intro.wishes.title"),
                note: Text("onboarding.intro.wishes.note")
            )
            featureCard(
                systemImage: "square.grid.2x2",
                title: Text("onboarding.intro.widgets.title"),
                note: Text("onboarding.intro.widgets.note")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var soloPage: some View {
        VStack(spacing: CorbieSpacing.l) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: CorbieMetrics.emptyStateIconSize, weight: .light))
                .foregroundStyle(CorbieColorPalette.ice)
                .accessibilityHidden(true)
            Text("onboarding.intro.page3.title")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
                .multilineTextAlignment(.center)
            Text("onboarding.intro.page3.note")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func featureCard(systemImage: String, title: Text, note: Text) -> some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                Image(systemName: systemImage)
                    .font(.system(size: CorbieSpacing.l, weight: .light))
                    .foregroundStyle(CorbieColorPalette.ice)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    title
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(CorbieColorPalette.text)
                    note
                        .corbieCaption()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: CorbieSpacing.xs) {
            ForEach(0 ..< OnboardingStepIndex.introPageCount, id: \.self) { index in
                Circle()
                    .fill(index == model.page ? CorbieColorPalette.ice : CorbieColorPalette.border)
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .accessibilityHidden(true)
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: CorbieMetrics.controlHeight)
        .clipShape(RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous))
        .disabled(model.isWorking)
        .opacity(model.isWorking ? 0.4 : 1)
        #if DEBUG
        .overlay(alignment: .top) {
            debugSignInButton
                .offset(y: -CorbieMetrics.controlHeight)
        }
        #endif
    }

    #if DEBUG
    private var debugSignInButton: some View {
        Button {
            Task { await model.debugSignIn() }
        } label: {
            Text("onboarding.debug.signin")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget)
        }
        .disabled(model.isWorking)
    }
    #endif

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = AppleSignInCredential(authorization: authorization) else { return }
            Task { await model.signIn(credential: credential) }
        case let .failure(error):
            model.signInFailed(error)
        }
    }
}

#Preview {
    OnboardingIntroView(model: OnboardingViewModel(environment: .preview(), appState: AppState()))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
}
