import CorbieCore
import SwiftUI

struct PeopleView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @State private var model = PeopleViewModel()

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                header
                if model.people.isEmpty {
                    if model.hasLoaded {
                        emptyState
                    }
                } else {
                    ForEach(model.people) { person in
                        NavigationLink(value: UsDestination.person(person.id)) {
                            PersonRow(
                                person: person,
                                radar: model.radar[person.id],
                                ownerSlot: environment.memberSlot(id: person.ownerMemberId),
                                ownerName: environment.memberName(id: person.ownerMemberId)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            AddToolbarItem {
                model.startAdding()
            }
        }
        .sheet(item: $model.editor, onDismiss: { model.reload() }) { mode in
            PersonEditorView(mode: mode)
        }
        .onAppear {
            if model.hasLoaded { model.reload() }
        }
        .task {
            model.bind(environment)
            await model.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text("people.title")
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text("people.subtitle")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CorbieSpacing.s)
    }

    private var emptyState: some View {
        EmptyState(
            systemImage: "person.crop.circle",
            title: String(localized: "people.empty.title"),
            monoNote: String(localized: "people.empty.note"),
            cta: EmptyStateAction(title: String(localized: "people.empty.action")) {
                model.startAdding()
            }
        )
        .padding(.top, CorbieSpacing.xxl)
    }
}

private struct PersonRow: View {
    @Environment(\.palette) private var palette

    let person: PersonDTO
    let radar: PeopleRadarSummary?
    let ownerSlot: MemberColorSlot?
    let ownerName: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(person.name)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                    if let caption {
                        Text(caption)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                    if let radar {
                        Text(radar.text.line())
                            .corbieMono()
                            .foregroundStyle(palette.accent)
                    }
                }
                Spacer(minLength: 0)
                MemberDot(slot: ownerSlot, accessibilityLabel: ownerName)
                    .padding(.top, CorbieSpacing.xxs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var caption: String? {
        PersonDates.rowCaption(for: person)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PeopleView()
            .usDestinations()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
