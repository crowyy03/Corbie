import CorbieCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL
    @State private var model = SettingsViewModel()
    @State private var sheet: SettingsSheet?
    @State private var confirmation: SettingsConfirmation?

    private let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")

    var body: some View {
        List {
            youSection
            partnerSection
            datesSection
            spaceSection
            subscriptionSection
            privacySection
            dataSection
            appearanceSection
            accountSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { model.attach(environment) }
        .onChange(of: environment.session) { _, _ in model.reloadFromSession() }
        .sheet(item: $sheet) { destination in
            sheetContent(destination)
        }
        .confirmationDialog(
            confirmation.map { Text($0.titleKey) } ?? Text("settings.title"),
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            confirmationActions
        } message: {
            if let confirmation {
                Text(confirmation.messageKey)
            }
        }
    }

    private var youSection: some View {
        Section {
            TextField(String(localized: "settings.you.name.placeholder"), text: $model.profile.displayName)
                .textInputAutocapitalization(.words)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .accessibilityLabel(Text("settings.you.name"))
            colorRow
            birthdayRow
            Button(String(localized: "settings.you.save")) {
                Task { await model.saveProfile() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.canSaveProfile ? CorbieColorPalette.ice : CorbieColorPalette.text2)
            .disabled(model.canSaveProfile == false)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
        } header: {
            SectionCaps(text: String(localized: "settings.section.you"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text("settings.you.color")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            MemberColorPicker(selection: $model.profile.colorKey)
        }
        .padding(.vertical, CorbieSpacing.xxs)
    }

    private var birthdayRow: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            ProfileBirthdayPicker(
                profile: $model.profile,
                toggleTitle: String(localized: "settings.you.birthday"),
                monthLabel: String(localized: "settings.you.birthday.month"),
                dayLabel: String(localized: "settings.you.birthday.day")
            )
            Text("settings.you.birthday.hint")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        }
        .padding(.vertical, CorbieSpacing.xxs)
    }

    private var partnerSection: some View {
        Section {
            if let partner = model.partner {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(verbatim: partner.displayName ?? environment.partnerName)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text(partnerJoinLine(partner))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                .padding(.vertical, CorbieSpacing.xxs)
                .accessibilityElement(children: .combine)
            } else {
                Text("settings.partner.none")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                row(titleKey: "settings.partner.invite") { sheet = .invite }
                row(titleKey: "settings.partner.havecode") { sheet = .join }
            }
        } header: {
            SectionCaps(text: String(localized: "settings.section.partner"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var datesSection: some View {
        Section {
            dateRow(
                titleKey: "settings.dates.together",
                pastOnly: true,
                date: Binding(get: { model.profile.togetherSince }, set: { model.profile.togetherSince = $0 })
            )
            dateRow(
                titleKey: "settings.dates.wedding",
                pastOnly: false,
                date: Binding(get: { model.weddingDate }, set: { model.weddingDate = $0 })
            )
        } header: {
            SectionCaps(text: String(localized: "settings.section.dates"))
        } footer: {
            Text("settings.dates.footer")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var spaceSection: some View {
        Section {
            Picker(selection: currencyBinding) {
                ForEach(model.currencies, id: \.self) { code in
                    Text(verbatim: code).tag(code)
                }
            } label: {
                Text("settings.space.currency")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .pickerStyle(.menu)
            .tint(CorbieColorPalette.ice)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)

            NavigationLink {
                SettingsNotificationsView()
            } label: {
                Text("settings.section.notifications")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .frame(minHeight: CorbieMetrics.minimumTapTarget)

            row(titleKey: "settings.space.import") { sheet = .calendarImport }
        } header: {
            SectionCaps(text: String(localized: "settings.section.space"))
        } footer: {
            Text("settings.space.currency.hint")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var subscriptionSection: some View {
        Section {
            Text(verbatim: model.subscriptionStatus.text)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            if model.subscriptionStatus.showsPlans {
                row(titleKey: "settings.subscription.plans") { sheet = .paywall(PaywallRequest(reason: .settings)) }
            }
            row(titleKey: "settings.subscription.manage") {
                guard let manageURL else { return }
                openURL(manageURL)
            }
            row(titleKey: "settings.subscription.restore") {
                Task { await model.restorePurchases() }
            }
        } header: {
            SectionCaps(text: String(localized: "settings.section.subscription"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var privacySection: some View {
        Section {
            Text("settings.privacy.copy")
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .padding(.vertical, CorbieSpacing.xxs)
            BusyTimesSharingToggle()
            ForEach(LegalPage.allCases) { page in
                row(titleKey: page.settingsTitleKey) { sheet = .legal(page) }
            }
        } header: {
            SectionCaps(text: String(localized: "settings.section.privacy"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var dataSection: some View {
        Section {
            row(titleKey: "settings.data.export") {
                Task { await model.exportData() }
            }
            if let url = model.exportURL {
                ShareLink(item: url) {
                    Text("settings.data.share")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.ice)
                }
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
        } header: {
            SectionCaps(text: String(localized: "settings.section.data"))
        } footer: {
            Text("settings.data.export.hint")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var appearanceSection: some View {
        Section {
            SegmentedPicker(selection: themeBinding, options: ThemePreference.allCases) { preference in
                String(localized: String.LocalizationValue("settings.appearance." + preference.rawValue))
            }
            .padding(.vertical, CorbieSpacing.xxs)
        } header: {
            SectionCaps(text: String(localized: "settings.section.appearance"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var accountSection: some View {
        Section {
            if model.isPaired {
                destructiveRow(titleKey: "settings.account.leave", isWorking: model.isLeaving) {
                    confirmation = .leave
                }
            }
            destructiveRow(titleKey: "settings.account.delete", isWorking: model.isDeleting) {
                confirmation = .delete
            }
        } header: {
            SectionCaps(text: String(localized: "settings.section.account"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    private var aboutSection: some View {
        Section {
            Text(verbatim: model.versionLine)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            #if DEBUG
            NavigationLink {
                DebugMenuView()
            } label: {
                Text("settings.developer")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            #endif
        } header: {
            SectionCaps(text: String(localized: "settings.section.about"))
        }
        .listRowBackground(CorbieColorPalette.surface)
    }

    @ViewBuilder private var confirmationActions: some View {
        switch confirmation {
        case .leave:
            Button(String(localized: "settings.account.leave"), role: .destructive) {
                Task { await model.leaveSpace() }
            }
        case .delete:
            Button(String(localized: "settings.account.delete"), role: .destructive) {
                Task { await model.deleteAccount() }
            }
        case nil:
            EmptyView()
        }
        Button(String(localized: "common.action.cancel"), role: .cancel) { confirmation = nil }
    }

    @ViewBuilder
    private func sheetContent(_ destination: SettingsSheet) -> some View {
        switch destination {
        case .invite:
            NavigationStack {
                InviteView(environment: environment, spaceId: environment.space?.id ?? UUID()) {
                    sheet = nil
                }
            }
        case .join:
            JoinSheet(code: nil)
        case .calendarImport:
            CalendarImportView()
        case let .paywall(request):
            PaywallView(request: request)
        case let .legal(page):
            if let url = page.url {
                LegalPageView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private func row(titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private func destructiveRow(
        titleKey: String,
        isWorking: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.warn)
                Spacer(minLength: 0)
                if isWorking {
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private func dateRow(titleKey: String, pastOnly: Bool, date: Binding<Date?>) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            Toggle(isOn: Binding(
                get: { date.wrappedValue != nil },
                set: { isOn in date.wrappedValue = isOn ? (date.wrappedValue ?? Date()) : nil }
            )) {
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .tint(CorbieColorPalette.ice)
            if date.wrappedValue != nil {
                let selection = Binding(get: { date.wrappedValue ?? Date() }, set: { date.wrappedValue = $0 })
                Group {
                    if pastOnly {
                        DatePicker(selection: selection, in: ...Date(), displayedComponents: .date) {
                            datePickerLabel(titleKey)
                        }
                    } else {
                        DatePicker(selection: selection, displayedComponents: .date) {
                            datePickerLabel(titleKey)
                        }
                    }
                }
                .datePickerStyle(.compact)
                .tint(CorbieColorPalette.ice)
            }
        }
        .padding(.vertical, CorbieSpacing.xxs)
    }

    private func datePickerLabel(_ titleKey: String) -> some View {
        Text(String(localized: String.LocalizationValue(titleKey)))
            .corbieBody()
            .foregroundStyle(CorbieColorPalette.text)
    }

    private func partnerJoinLine(_ partner: MemberDTO) -> String {
        guard let space = model.space else { return String(localized: "settings.partner.created") }
        if space.creatorMemberId == partner.id { return String(localized: "settings.partner.created") }
        guard let joinedAt = partner.joinedAt else { return String(localized: "settings.partner.created") }
        return String.localizedStringWithFormat(
            String(localized: "settings.partner.joined"),
            joinedAt.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { isOn in if isOn == false { confirmation = nil } })
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { model.displayCurrency },
            set: { code in Task { await model.setCurrency(code) } }
        )
    }

    private var themeBinding: Binding<ThemePreference> {
        Binding(
            get: { environment.theme.preference },
            set: { environment.theme.setPreference($0) }
        )
    }

}

enum SettingsSheet: Identifiable {
    case invite
    case join
    case calendarImport
    case paywall(PaywallRequest)
    case legal(LegalPage)

    var id: String {
        switch self {
        case .invite: return "invite"
        case .join: return "join"
        case .calendarImport: return "calendar"
        case let .paywall(request): return "paywall." + request.id.uuidString
        case let .legal(page): return "legal." + page.rawValue
        }
    }
}

enum SettingsConfirmation: Identifiable {
    case leave
    case delete

    var id: String {
        switch self {
        case .leave: return "leave"
        case .delete: return "delete"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .leave: return "settings.account.leave.confirm"
        case .delete: return "settings.account.delete.confirm"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .leave: return "settings.account.leave.note"
        case .delete: return "settings.account.delete.note"
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .environment(AppEnvironment.previewSignedIn())
}
#endif
