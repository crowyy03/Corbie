import CorbieCore
import SwiftUI

struct OnboardingProfileView: View {
    @Environment(\.palette) private var palette

    @Bindable var model: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.xl) {
                Text("onboarding.profile.title")
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)

                TextFieldRow(
                    label: String(localized: "onboarding.profile.name.label"),
                    placeholder: String(localized: "onboarding.profile.name.placeholder"),
                    hint: String(localized: "onboarding.profile.name.hint"),
                    text: $model.profile.displayName
                )
                .textInputAutocapitalization(.words)

                colorRow
                togetherRow
                birthdayRow

                PrimaryButton(title: String(localized: "onboarding.profile.continue")) {
                    Task { await model.continueFromProfile() }
                }
                .disabled(model.profile.isComplete == false || model.isWorking)
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var colorRow: some View {
        FieldRow(
            label: String(localized: "onboarding.profile.color.label"),
            hint: String(localized: "onboarding.profile.color.hint")
        ) {
            MemberColorPicker(
                selection: $model.profile.colorSlot,
                partnerSlot: model.partnerSlot,
                partnerName: model.partnerName
            )
        }
    }

    private var togetherRow: some View {
        FieldRow(
            label: String(localized: "onboarding.profile.together.label"),
            hint: String(localized: "onboarding.profile.together.hint")
        ) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Toggle(isOn: togetherEnabled) {
                    Text("onboarding.profile.together.toggle")
                        .corbieBody()
                        .foregroundStyle(palette.text)
                }
                .tint(palette.accent)

                if model.profile.togetherSince != nil {
                    DatePicker(
                        selection: togetherDate,
                        in: ...Date(),
                        displayedComponents: .date
                    ) {
                        Text("onboarding.profile.together.label")
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    }
                    .datePickerStyle(.compact)
                    .tint(palette.accent)
                }
            }
        }
    }

    private var birthdayRow: some View {
        FieldRow(
            label: String(localized: "onboarding.profile.birthday.label"),
            hint: String(localized: "onboarding.profile.birthday.hint")
        ) {
            ProfileBirthdayPicker(
                profile: $model.profile,
                toggleTitle: String(localized: "onboarding.profile.birthday.toggle"),
                monthLabel: String(localized: "onboarding.profile.birthday.month"),
                dayLabel: String(localized: "onboarding.profile.birthday.day")
            )
        }
    }

    private var togetherEnabled: Binding<Bool> {
        Binding(
            get: { model.profile.togetherSince != nil },
            set: { isOn in
                model.profile.togetherSince = isOn ? (model.profile.togetherSince ?? Date()) : nil
            }
        )
    }

    private var togetherDate: Binding<Date> {
        Binding(
            get: { model.profile.togetherSince ?? Date() },
            set: { model.profile.togetherSince = $0 }
        )
    }
}

#if DEBUG
#Preview {
    OnboardingProfileView(model: OnboardingViewModel(environment: .preview(), appState: AppState()))
        .background(CorbieTheme.sand.palette.bg)
}
#endif
