import CorbieCore
import SwiftUI
import UIKit

struct FreeTimeView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = FreeTimeViewModel()

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    rangePicker
                    filterChips
                    content
                }
                .padding(CorbieSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.bg)
            .navigationTitle(String(localized: "freetime.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("common.action.close"))
                }
            }
            .refreshable {
                await model.refresh()
            }
            .task {
                await model.open(environment)
            }
            .onChange(of: model.range) {
                Task { await model.load() }
            }
            .onChange(of: model.filters) {
                Task { await model.load() }
            }
            .onChange(of: environment.currentMember?.sharesBusyTimes) {
                Task { await model.load() }
            }
            .sheet(item: $model.sheet, onDismiss: { Task { await model.refresh() } }) { sheet in
                sheetContent(sheet)
            }
        }
    }

    private var rangePicker: some View {
        @Bindable var model = model

        return SegmentedPicker(selection: $model.range, options: FreeTimeRange.allCases) { option in
            String(localized: String.LocalizationValue(option.titleKey))
        }
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private var filterChips: some View {
        @Bindable var model = model

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CorbieSpacing.xs) {
                filterChip(titleKey: "freetime.filter.evenings", isOn: $model.eveningsOnly)
                filterChip(titleKey: "freetime.filter.weekends", isOn: $model.weekendsOnly)
                filterChip(titleKey: "freetime.filter.long", isOn: $model.longSlotsOnly)
            }
        }
    }

    private func filterChip(titleKey: String, isOn: Binding<Bool>) -> some View {
        let title = String(localized: String.LocalizationValue(titleKey))
        return Button {
            isOn.wrappedValue.toggle()
        } label: {
            Chip(label: title, isSelected: isOn.wrappedValue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isOn.wrappedValue ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .tint(palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CorbieSpacing.xxl)
        case .notPaired:
            EmptyState(
                systemImage: "person.2",
                title: String(localized: "freetime.unpaired.title"),
                monoNote: String(localized: "freetime.unpaired.note")
            )
            .padding(.vertical, CorbieSpacing.l)
        case .viewerNotSharing:
            viewerExplainer
        case .partnerNotSharing:
            partnerExplainer
        case .calendarDenied:
            deniedExplainer
        case .unreadable:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: String(localized: "freetime.unreadable.title"),
                monoNote: String(localized: "freetime.unreadable.note")
            )
            .padding(.vertical, CorbieSpacing.l)
        case .noSlots:
            EmptyState(
                systemImage: "calendar.badge.exclamationmark",
                title: String(localized: "freetime.empty.title"),
                monoNote: String(localized: "freetime.empty.note")
            )
            .padding(.vertical, CorbieSpacing.l)
        case let .slots(slots):
            slotList(slots)
        }
    }

    private var viewerExplainer: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Text("freetime.you.title")
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Text("freetime.you.note")
                    .corbieCaption()
                    .foregroundStyle(palette.text2)
                BusyTimesSharingToggle()
            }
        }
    }

    private var partnerExplainer: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "freetime.partner.title"),
                        environment.partnerName
                    )
                )
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)
                Text("freetime.partner.note")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                SecondaryButton(title: String(localized: "freetime.partner.ask")) {
                    model.nudgePartner()
                }
            }
        }
    }

    private var deniedExplainer: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Text("calendar.import.denied.title")
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Text("calendar.import.denied.note")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    SecondaryButton(title: String(localized: "settings.notifications.permission.open")) {
                        openURL(url)
                    }
                }
            }
        }
    }

    private func slotList(_ slots: [FreeSlot]) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            SectionCaps(text: String(localized: "freetime.list.caps"))
            LazyVStack(spacing: CorbieSpacing.xs) {
                ForEach(slots) { slot in
                    Button {
                        model.selectSlot(slot)
                    } label: {
                        slotRow(slot)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(model.rowText.accessibilityLabel(for: slot, partnerName: environment.partnerName))
                    )
                }
            }
        }
    }

    private func slotRow(_ slot: FreeSlot) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(verbatim: model.rowText.title(for: slot))
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    if let partnerTime = model.rowText.partnerTime(
                        for: slot,
                        partnerName: environment.partnerName
                    ) {
                        Text(verbatim: partnerTime)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                }
                Spacer(minLength: CorbieSpacing.xs)
                Text(verbatim: model.rowText.duration(for: slot))
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: FreeTimeSheet) -> some View {
        switch sheet {
        case .privacy:
            FreeTimePrivacySheet()
        case let .editor(target):
            EventEditorView(target: target, people: model.people, calendar: model.calendar)
        }
    }
}

#if DEBUG
#Preview {
    FreeTimeView()
        .environment(AppEnvironment.previewSignedIn())
}
#endif
