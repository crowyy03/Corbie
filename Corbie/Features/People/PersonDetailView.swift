import CorbieCore
import SwiftUI

struct PersonDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PersonDetailViewModel

    init(personId: UUID) {
        _model = State(initialValue: PersonDetailViewModel(personId: personId))
    }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                if let person = model.person {
                    header(person)
                    factsCard(person)
                    giftIdeas
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(String(localized: "people.detail.edit")) {
                        model.startEditingPerson()
                    }
                    Button(String(localized: "people.detail.delete"), role: .destructive) {
                        model.isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("people.detail.menu"))
            }
        }
        .confirmationDialog(
            Text("people.detail.delete.confirm"),
            isPresented: $model.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "people.detail.delete"), role: .destructive) {
                Task { await model.deletePerson() }
            }
            Button(String(localized: "people.editor.cancel"), role: .cancel) {}
        }
        .sheet(item: $model.editor, onDismiss: { model.reload() }) { mode in
            PersonEditorView(mode: mode)
        }
        .sheet(item: $model.giftEditor, onDismiss: { model.reload() }) { mode in
            GiftIdeaEditorView(personId: model.personId, mode: mode)
        }
        .onChange(of: model.isGone) {
            if model.isGone { dismiss() }
        }
        .task {
            model.bind(environment)
            await model.load()
        }
    }

    private func header(_ person: PersonDTO) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(person.name)
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
                .accessibilityAddTraits(.isHeader)
            if let radar = model.radar {
                Text(radar.line())
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.ice)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CorbieSpacing.s)
    }

    private func factsCard(_ person: PersonDTO) -> some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                fact(key: "people.detail.relation", value: person.relation)
                fact(key: "people.detail.birthday", value: PersonBirthday.text(person))
                owner(person)
                fact(key: "people.detail.note", value: person.note)
            }
        }
    }

    @ViewBuilder
    private func fact(key: String, value: String?) -> some View {
        if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                SectionCaps(text: String(localized: String.LocalizationValue(key)))
                Text(value)
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func owner(_ person: PersonDTO) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            SectionCaps(text: String(localized: "people.detail.owner"))
            HStack(spacing: CorbieSpacing.xs) {
                MemberDot(color: environment.memberColor(id: person.ownerMemberId))
                Text(environment.memberName(id: person.ownerMemberId))
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var giftIdeas: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            HStack {
                SectionCaps(text: String(localized: "people.detail.gifts"))
                Spacer(minLength: 0)
                Button {
                    model.startAddingIdea()
                } label: {
                    Image(systemName: "plus")
                        .frame(
                            minWidth: CorbieMetrics.minimumTapTarget,
                            minHeight: CorbieMetrics.minimumTapTarget
                        )
                }
                .accessibilityLabel(Text("people.detail.gifts.add"))
            }
            if model.ideas.isEmpty {
                if model.hasLoaded {
                    EmptyState(
                        systemImage: "gift",
                        title: String(localized: "people.detail.gifts.empty"),
                        monoNote: String(localized: "people.detail.gifts.empty.note")
                    )
                    .padding(.vertical, CorbieSpacing.m)
                }
            } else {
                ForEach(model.ideas) { idea in
                    GiftIdeaRow(
                        idea: idea,
                        price: model.priceText(idea),
                        toggle: { Task { await model.toggle(idea) } },
                        edit: { model.startEditingIdea(idea) },
                        remove: { Task { await model.deleteIdea(idea) } }
                    )
                }
            }
        }
        .padding(.top, CorbieSpacing.s)
    }
}

private struct GiftIdeaRow: View {
    let idea: GiftIdeaDTO
    let price: String?
    let toggle: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                Button(action: toggle) {
                    Image(systemName: idea.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(idea.isDone ? CorbieColorPalette.ice : CorbieColorPalette.text2)
                        .frame(
                            minWidth: CorbieMetrics.minimumTapTarget,
                            minHeight: CorbieMetrics.minimumTapTarget,
                            alignment: .leading
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("people.gift.done"))
                .accessibilityAddTraits(idea.isDone ? [.isSelected, .isButton] : .isButton)

                Button(action: edit) {
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(idea.title)
                            .corbieBody()
                            .foregroundStyle(idea.isDone ? CorbieColorPalette.text2 : CorbieColorPalette.text)
                            .multilineTextAlignment(.leading)
                        if let caption {
                            Text(caption)
                                .corbieMono()
                                .foregroundStyle(CorbieColorPalette.text2)
                                .multilineTextAlignment(.leading)
                        }
                        if let note = idea.note, note.isEmpty == false {
                            Text(note)
                                .corbieCaption()
                                .foregroundStyle(CorbieColorPalette.text2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let url = link {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(CorbieColorPalette.ice)
                            .frame(
                                minWidth: CorbieMetrics.minimumTapTarget,
                                minHeight: CorbieMetrics.minimumTapTarget,
                                alignment: .trailing
                            )
                    }
                    .accessibilityLabel(Text("people.gift.open"))
                }
            }
        }
        .contextMenu {
            Button(String(localized: "people.detail.gifts.remove"), role: .destructive, action: remove)
        }
    }

    private var caption: String? {
        let host = link?.host()
        switch (price, host) {
        case let (.some(price), .some(host)):
            return String(localized: "people.gift.caption", defaultValue: "\(price) \u{00B7} \(host)")
        case let (.some(price), .none):
            return price
        case let (.none, .some(host)):
            return host
        case (.none, .none):
            return nil
        }
    }

    private var link: URL? {
        guard let url = idea.url else { return nil }
        return URL(string: url)
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(personId: UUID())
    }
    .environment(AppEnvironment.preview())
}
