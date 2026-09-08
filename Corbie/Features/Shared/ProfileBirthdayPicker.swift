import CorbieCore
import SwiftUI

struct ProfileBirthdayPicker: View {
    @Environment(\.palette) private var palette

    @Binding var profile: ProfileDraft
    let toggleTitle: String
    let monthLabel: String
    let dayLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            Toggle(isOn: enabled) {
                Text(toggleTitle)
                    .corbieBody()
                    .foregroundStyle(palette.text)
            }
            .tint(palette.accent)

            if profile.hasBirthday {
                HStack(spacing: CorbieSpacing.m) {
                    Picker(selection: month) {
                        ForEach(1 ... 12, id: \.self) { value in
                            Text(verbatim: PersonBirthday.monthName(value)).tag(value)
                        }
                    } label: {
                        Text(monthLabel)
                    }
                    .pickerStyle(.menu)
                    .tint(palette.accent)

                    Picker(selection: day) {
                        ForEach(1 ... PersonBirthday.dayCount(month: profile.birthdayMonth ?? 1), id: \.self) { value in
                            Text(verbatim: value.formatted()).tag(value)
                        }
                    } label: {
                        Text(dayLabel)
                    }
                    .pickerStyle(.menu)
                    .tint(palette.accent)
                }
            }
        }
    }

    private var enabled: Binding<Bool> {
        Binding(
            get: { profile.hasBirthday },
            set: { isOn in profile.setBirthday(enabled: isOn) }
        )
    }

    private var month: Binding<Int> {
        Binding(
            get: { profile.birthdayMonth ?? 1 },
            set: { value in
                profile.birthdayMonth = value
                profile.clampBirthdayDay()
            }
        )
    }

    private var day: Binding<Int> {
        Binding(
            get: { profile.birthdayDay ?? 1 },
            set: { profile.birthdayDay = $0 }
        )
    }
}
