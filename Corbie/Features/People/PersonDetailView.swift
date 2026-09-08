import CorbieCore
import SwiftUI

struct PersonDetailView: View {
    @Environment(\.palette) private var palette

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
                    datesCard
                    giftIdeas
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
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
        .sheet(item: $model.dateEditor, onDismiss: { model.reload() }) { mode in
            PersonDateEditorView(personId: model.personId, mode: mode)
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
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            if let radar = model.radar {
                Text(radar.text.line())
                    .corbieMono()
                    .foregroundStyle(palette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CorbieSpacing.s)
    }

    private func factsCard(_ person: PersonDTO) -> some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                fact(key: "people.detail.relation", value: person.relation)
                owner(person)
                fact(key: "people.detail.note", value: person.note)
            }
        }
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            HStack {
                SectionCaps(text: String(localized: "people.detail.dates"))
                Spacer(minLength: 0)
                Button {
                    model.startAddingDate()
                } label: {
                    Image(systemName: "plus")
                        .frame(
                            minWidth: CorbieMetrics.minimumTapTarget,
                            minHeight: CorbieMetrics.minimumTapTarget
                        )
                }
                .accessibilityLabel(Text("people.detail.dates.add"))
            }
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    if model.dateLines.isEmpty {
                        Text("people.detail.dates.empty")
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    } else {
                        ForEach(model.dateLines) { line in
                            PersonDateRowView(
                                line: line,
                                edit: { model.startEditingDate(line) },
                                remove: { Task { await model.deleteDate(line) } }
                            )
                        }
                    }
                }
            }
        }
        .padding(.top, CorbieSpacing.s)
    }

    @ViewBuilder
    private func fact(key: String, value: String?) -> some View {
        if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                SectionCaps(text: String(localized: String.LocalizationValue(key)))
                Text(value)
                    .corbieBody()
                    .foregroundStyle(palette.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func owner(_ person: PersonDTO) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            SectionCaps(text: String(localized: "people.detail.owner"))
            HStack(spacing: CorbieSpacing.xs) {
                MemberDot(slot: environment.memberSlot(id: person.ownerMemberId))
                Text(environment.memberName(id: person.ownerMemberId))
                    .corbieBody()
                    .foregroundStyle(palette.text)
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

private struct PersonDateRowView: View {
    @Environment(\.palette) private var palette

    let line: PersonDateLine
    let edit: () -> Void
    let remove: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(line.title)
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    if let caption = line.caption {
                        Text(caption)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if let dayText = line.dayText {
                    Text(dayText)
                        .corbieBody()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(String(localized: "people.detail.dates.edit"), action: edit)
            if line.isBirthday == false {
                Button(String(localized: "people.detail.dates.remove"), role: .destructive, action: remove)
            }
        }
    }
}

private struct GiftIdeaRow: View {
    @Environment(\.palette) private var palette

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
                        .foregroundStyle(idea.isDone ? palette.accent : palette.text2)
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
                            .foregroundStyle(idea.isDone ? palette.text2 : palette.text)
                            .multilineTextAlignment(.leading)
                        if let caption {
                            Text(caption)
                                .corbieMono()
                                .foregroundStyle(palette.text2)
                                .multilineTextAlignment(.leading)
                        }
                        if let note = idea.note, note.isEmpty == false {
                            Text(note)
                                .corbieCaption()
                                .foregroundStyle(palette.text2)
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
                            .foregroundStyle(palette.accent)
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

#if DEBUG
#Preview {
    NavigationStack {
        PersonDetailView(personId: UUID())
    }
    .environment(AppEnvironment.preview())
}
#endif
