import CorbieCore
import SwiftUI

struct PersonDestination: Hashable {
    let id: UUID
}

struct PeopleView: View {
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
                        NavigationLink(value: PersonDestination(id: person.id)) {
                            PersonRow(
                                person: person,
                                radar: model.radar[person.id],
                                ownerColor: environment.memberColor(id: person.ownerMemberId),
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
        .background(CorbieColorPalette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PersonDestination.self) { destination in
            PersonDetailView(personId: destination.id)
        }
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
                .foregroundStyle(CorbieColorPalette.text)
                .accessibilityAddTraits(.isHeader)
            Text("people.subtitle")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
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
    let person: PersonDTO
    let radar: PeopleRadarSummary?
    let ownerColor: Color
    let ownerName: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(person.name)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(CorbieColorPalette.text)
                    if let caption {
                        Text(caption)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                    if let radar {
                        Text(radar.text.line())
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.ice)
                    }
                }
                Spacer(minLength: 0)
                MemberDot(color: ownerColor, accessibilityLabel: ownerName)
                    .padding(.top, CorbieSpacing.xxs)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var caption: String? {
        let relation = person.relation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let birthday = PersonBirthday.text(person)
        switch (relation?.isEmpty == false ? relation : nil, birthday) {
        case let (.some(relation), .some(birthday)):
            return String(localized: "people.row.caption", defaultValue: "\(relation) \u{00B7} \(birthday)")
        case let (.some(relation), .none):
            return relation
        case let (.none, .some(birthday)):
            return birthday
        case (.none, .none):
            return nil
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PeopleView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
