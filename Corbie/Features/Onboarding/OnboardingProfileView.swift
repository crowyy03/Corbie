import CorbieCore
import SwiftUI

struct OnboardingProfileView: View {
    @Bindable var model: OnboardingViewModel

    private let swatchSize: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.xl) {
                Text("onboarding.profile.title")
                    .corbieScreenTitle()
                    .foregroundStyle(CorbieColorPalette.text)

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
            HStack(spacing: CorbieSpacing.xs) {
                ForEach(CorbieColorPalette.partnerPalette) { key in
                    swatch(key)
                }
            }
        }
    }

    private func swatch(_ key: MemberColorKey) -> some View {
        let isSelected = model.profile.colorKey == key
        return Button {
            model.profile.colorKey = key
        } label: {
            Circle()
                .fill(key.color)
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? CorbieColorPalette.ice : .clear,
                            lineWidth: CorbieMetrics.hairline * 2
                        )
                        .padding(-CorbieSpacing.xxs)
                }
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorName(key))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
                        .foregroundStyle(CorbieColorPalette.text)
                }
                .tint(CorbieColorPalette.ice)

                if model.profile.togetherSince != nil {
                    DatePicker(
                        selection: togetherDate,
                        in: ...Date(),
                        displayedComponents: .date
                    ) {
                        Text("onboarding.profile.together.label")
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    .datePickerStyle(.compact)
                    .tint(CorbieColorPalette.ice)
                }
            }
        }
    }

    private var birthdayRow: some View {
        FieldRow(
            label: String(localized: "onboarding.profile.birthday.label"),
            hint: String(localized: "onboarding.profile.birthday.hint")
        ) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Toggle(isOn: birthdayEnabled) {
                    Text("onboarding.profile.birthday.toggle")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                }
                .tint(CorbieColorPalette.ice)

                if model.profile.hasBirthday {
                    HStack(spacing: CorbieSpacing.m) {
                        Picker(selection: birthdayMonth) {
                            ForEach(1 ... 12, id: \.self) { month in
                                Text(verbatim: monthName(month)).tag(month)
                            }
                        } label: {
                            Text("onboarding.profile.birthday.month")
                        }
                        .pickerStyle(.menu)
                        .tint(CorbieColorPalette.ice)

                        Picker(selection: birthdayDay) {
                            ForEach(1 ... dayCount, id: \.self) { day in
                                Text(verbatim: day.formatted()).tag(day)
                            }
                        } label: {
                            Text("onboarding.profile.birthday.day")
                        }
                        .pickerStyle(.menu)
                        .tint(CorbieColorPalette.ice)
                    }
                }
            }
        }
    }

    private var dayCount: Int {
        ProfileDraft.dayCount(inMonth: model.profile.birthdayMonth ?? 1)
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

    private var birthdayEnabled: Binding<Bool> {
        Binding(
            get: { model.profile.hasBirthday },
            set: { isOn in model.profile.setBirthday(enabled: isOn) }
        )
    }

    private var birthdayMonth: Binding<Int> {
        Binding(
            get: { model.profile.birthdayMonth ?? 1 },
            set: { month in
                model.profile.birthdayMonth = month
                model.profile.clampBirthdayDay()
            }
        )
    }

    private var birthdayDay: Binding<Int> {
        Binding(
            get: { model.profile.birthdayDay ?? 1 },
            set: { model.profile.birthdayDay = $0 }
        )
    }

    private func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.standaloneMonthSymbols
        guard symbols.indices.contains(month - 1) else { return month.formatted() }
        return symbols[month - 1]
    }

    private func colorName(_ key: MemberColorKey) -> String {
        switch key {
        case .p1: return String(localized: "onboarding.profile.color.p1")
        case .p2: return String(localized: "onboarding.profile.color.p2")
        case .p3: return String(localized: "onboarding.profile.color.p3")
        case .p4: return String(localized: "onboarding.profile.color.p4")
        case .p5: return String(localized: "onboarding.profile.color.p5")
        case .p6: return String(localized: "onboarding.profile.color.p6")
        }
    }
}

#Preview {
    OnboardingProfileView(model: OnboardingViewModel(environment: .preview(), appState: AppState()))
        .background(CorbieColorPalette.bg)
}
