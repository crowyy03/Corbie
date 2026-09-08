import CorbieCore
import SwiftUI

struct CapsulesView: View {
    @Environment(\.palette) private var palette

    var startsWithEditor = false

    @Environment(AppEnvironment.self) private var environment
    @State private var model = CapsulesViewModel()

    private let dates = RelativeDateText()
    private let now = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                if model.capsules.isEmpty {
                    if model.isLoading == false {
                        empty
                    }
                } else {
                    ForEach(model.sections(now: now), id: \.section) { group in
                        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                            SectionCaps(text: String(localized: group.section.titleKey))
                            ForEach(group.capsules) { capsule in
                                row(capsule)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .background(palette.bg)
        .navigationTitle(String(localized: "capsules.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            AddToolbarItem {
                model.startNew()
            }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case let .editor(target):
                CapsuleEditorView(target: target) {
                    await model.load(environment)
                }
            case let .reading(capsule):
                CapsuleOpenView(capsule: capsule) { opened in
                    model.replace(opened)
                }
            }
        }
        .task {
            await model.load(environment)
            if startsWithEditor, model.sheet == nil {
                model.startNew()
            }
        }
    }

    private var empty: some View {
        EmptyState(
            systemImage: "envelope",
            title: String(localized: "capsules.empty.title"),
            monoNote: String(localized: "capsules.empty.note"),
            cta: EmptyStateAction(title: String(localized: "capsules.action.new")) {
                model.startNew()
            }
        )
        .padding(.top, CorbieSpacing.xxl)
    }

    @ViewBuilder
    private func row(_ capsule: CapsuleDTO) -> some View {
        let state = model.state(for: capsule, now: now)
        if state == .waiting {
            card(capsule, state: state)
                .accessibilityElement(children: .combine)
        } else {
            Button {
                model.select(capsule, now: now)
            } label: {
                card(capsule, state: state)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }

    private func card(_ capsule: CapsuleDTO, state: CapsuleRowState) -> some View {
        Card(isHighlighted: state.isHighlighted) {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                Image(systemName: state.systemImage)
                    .foregroundStyle(state.isHighlighted ? palette.accent : palette.text2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(title(for: capsule))
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    Text(caption(for: capsule, state: state))
                        .corbieCaption()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.leading)
                    Text(detail(for: capsule, state: state))
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func title(for capsule: CapsuleDTO) -> String {
        capsule.title.isEmpty ? String(localized: "capsules.row.untitled") : capsule.title
    }

    private func caption(for capsule: CapsuleDTO, state: CapsuleRowState) -> String {
        switch state {
        case .waiting:
            return String(
                format: String(localized: "capsules.row.waiting"),
                environment.memberName(id: capsule.authorMemberId)
            )
        case .ready:
            return String(localized: "capsules.row.ready")
        case .sealed:
            return String(
                format: String(localized: "capsules.row.sealed"),
                environment.memberName(id: capsule.recipientMemberId)
            )
        case .opened:
            return capsule.isReadByBoth
                ? String(localized: "capsules.row.readbyboth")
                : String(localized: "capsules.row.readbyyou")
        }
    }

    private func detail(for capsule: CapsuleDTO, state: CapsuleRowState) -> String {
        if state == .opened, let openedAt = capsule.openedAt {
            return String(
                format: String(localized: "capsules.row.opened"),
                dates.dueText(for: openedAt, now: now)
            )
        }
        guard let opensAt = capsule.opensAt else { return "" }
        return String(
            format: String(localized: "capsules.row.opens"),
            dates.dueText(for: opensAt, now: now),
            dates.relativeDay(for: opensAt, now: now)
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CapsulesView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
