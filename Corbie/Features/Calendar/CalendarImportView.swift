import CorbieCore
import SwiftUI

struct CalendarImportView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: CalendarImportViewModel

    @MainActor
    init(client: any EventStoreClient = SystemEventStoreClient()) {
        _model = State(initialValue: CalendarImportViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    Text("calendar.import.note")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                    content
                }
                .padding(CorbieSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(CorbieColorPalette.bg)
            .navigationTitle(String(localized: "calendar.import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel")) {
                        dismiss()
                    }
                }
            }
            .task {
                await model.prepare(environment)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .importing:
            ProgressView()
                .frame(maxWidth: .infinity)
                .tint(CorbieColorPalette.ice)
        case .denied:
            EmptyState(
                systemImage: "calendar.badge.exclamationmark",
                title: String(localized: "calendar.import.denied.title"),
                monoNote: String(localized: "calendar.import.denied.note")
            )
        case .picking:
            picker
        case let .finished(count):
            EmptyState(
                systemImage: "checkmark.circle",
                title: String(localized: "calendar.import.done.title"),
                monoNote: String.localizedStringWithFormat(
                    String(localized: "calendar.import.done.note"),
                    count
                ),
                cta: EmptyStateAction(title: String(localized: "common.action.done")) {
                    dismiss()
                }
            )
        }
    }

    @ViewBuilder
    private var picker: some View {
        if model.calendars.isEmpty {
            Text("calendar.import.empty")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        } else {
            VStack(spacing: CorbieSpacing.xs) {
                ForEach(model.calendars) { calendar in
                    row(calendar)
                }
            }
            PrimaryButton(title: String(localized: "calendar.import.action")) {
                Task { await model.runImport(environment) }
            }
            .disabled(model.canImport == false)
            .padding(.top, CorbieSpacing.s)
        }
    }

    private func row(_ calendar: ImportedCalendar) -> some View {
        let isSelected = model.selection.contains(calendar.id)
        return Button {
            model.toggle(calendar.id)
        } label: {
            Card {
                HStack(spacing: CorbieSpacing.s) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? CorbieColorPalette.ice : CorbieColorPalette.text2)
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(calendar.title)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                            .multilineTextAlignment(.leading)
                        if let sourceTitle = calendar.sourceTitle {
                            Text(sourceTitle)
                                .corbieMono()
                                .foregroundStyle(CorbieColorPalette.text2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct PreviewEventStoreClient: EventStoreClient {
    func requestAccess() async throws -> Bool { true }

    func calendars() async throws -> [ImportedCalendar] {
        [ImportedCalendar(id: "preview.home", title: "Home", sourceTitle: "iCloud")]
    }

    func events(calendarIds: [String], from: Date, to: Date) async throws -> [ImportedEvent] { [] }
}

#if DEBUG
#Preview {
    CalendarImportView(client: PreviewEventStoreClient())
        .environment(AppEnvironment.preview())
}
#endif
