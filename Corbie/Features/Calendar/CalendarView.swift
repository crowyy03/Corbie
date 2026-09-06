import CorbieCore
import SwiftUI

struct CalendarEventRoute: Hashable {
    let id: UUID
}

struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var model = CalendarViewModel()
    @State private var editorTarget: EventEditorTarget?
    @State private var isImporting = false
    @State private var isFreeTimePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                Text("tab.calendar.title")
                    .corbieScreenTitle()
                    .foregroundStyle(CorbieColorPalette.text)
                Card {
                    CalendarMonthView(model: model) { day in
                        model.select(day)
                    }
                }
                section
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CorbieColorPalette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(String(localized: "calendar.import.action")) {
                        isImporting = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("calendar.actions.label"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openFreeTime()
                } label: {
                    Image(systemName: "clock.badge.checkmark")
                        .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("freetime.title"))
            }
            AddToolbarItem {
                editorTarget = .create(model.draftStart())
            }
            UsPillToolbarItem()
        }
        .task {
            await model.load(environment)
        }
        .refreshable {
            await model.load(environment)
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetReloadRequest.notificationName)) { _ in
            model.scheduleReload(environment)
        }
        .onChange(of: appState.route) {
            consumeRoute()
        }
        .sheet(item: $editorTarget) { target in
            EventEditorView(target: target, people: model.people, calendar: model.calendar)
        }
        .sheet(isPresented: $isImporting) {
            CalendarImportView()
        }
        .sheet(isPresented: $isFreeTimePresented) {
            FreeTimeView()
        }
        .navigationDestination(for: CalendarEventRoute.self) { route in
            EventDetailView(eventId: route.id, calendar: model.calendar)
        }
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            sectionHeader
            sectionBody
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: CorbieSpacing.s) {
            SectionCaps(text: sectionTitle)
            Spacer(minLength: CorbieSpacing.xs)
            if model.selectedDay != nil {
                Button(String(localized: "calendar.upcoming.clear")) {
                    model.selectedDay = nil
                }
                .buttonStyle(.plain)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
            Button(String(localized: "common.action.add")) {
                editorTarget = .create(model.draftStart())
            }
            .buttonStyle(.plain)
            .corbieMono()
            .foregroundStyle(CorbieColorPalette.ice)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        let entries = model.sectionEntries
        if entries.isEmpty {
            if model.isLoading {
                ProgressView()
                    .tint(CorbieColorPalette.ice)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CorbieSpacing.l)
            } else if model.selectedDay == nil {
                EmptyState(
                    systemImage: "calendar",
                    title: String(localized: "calendar.placeholder.title"),
                    monoNote: String(localized: "calendar.placeholder.note"),
                    cta: EmptyStateAction(title: String(localized: "calendar.upcoming.add")) {
                        editorTarget = .create(model.draftStart())
                    }
                )
                .padding(.vertical, CorbieSpacing.l)
            } else {
                Text("calendar.day.empty")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        } else {
            LazyVStack(spacing: CorbieSpacing.xs) {
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: CalendarEntry) -> some View {
        if let eventId = entry.eventId {
            NavigationLink(value: CalendarEventRoute(id: eventId)) {
                CalendarEntryRow(entry: entry, model: model)
            }
            .buttonStyle(.plain)
        } else {
            CalendarEntryRow(entry: entry, model: model)
        }
    }

    private var sectionTitle: String {
        guard let selectedDay = model.selectedDay else {
            return String(localized: "calendar.upcoming.title")
        }
        return model.formatting.shortDate(selectedDay)
    }

    private func openFreeTime() {
        guard environment.premiumGate.isPremium else {
            environment.premiumGate.presentPaywall(reason: .settings)
            return
        }
        isFreeTimePresented = true
    }

    private func consumeRoute() {
        guard appState.route == .calendar else { return }
        model.showCurrentMonth()
        appState.route = nil
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CalendarView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
