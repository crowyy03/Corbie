import CorbieCore
import SwiftUI

struct ChoresView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @State private var model: ChoresViewModel?

    private let copy = ChoreCopy()

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            if let model, model.hasLoaded {
                content(model)
            }
        }
        .navigationTitle(String(localized: "chore.title"))
        .navigationBarTitleDisplayMode(.large)
        .paywallBanner()
        .task { await start() }
        .onChange(of: environment.session) {
            Task { await model?.apply(context) }
        }
    }

    @ViewBuilder private func content(_ model: ChoresViewModel) -> some View {
        switch model.state {
        case .notStarted:
            intro(model)
        case .building:
            builder(model)
        case .yourTurnToRate:
            rating(model)
        case .waitingForPartner:
            waiting(model)
        case .readyToReveal:
            ready(model)
        case .revealed:
            reveal(model)
        case let .applied(date), let .needsResplit(date):
            done(model, appliedAt: date)
        }
    }

    private func intro(_ model: ChoresViewModel) -> some View {
        VStack(spacing: CorbieSpacing.m) {
            EmptyState(
                systemImage: "arrow.left.arrow.right",
                title: String(localized: "chore.intro.title"),
                subtitle: String(localized: "chore.intro.subtitle"),
                monoNote: String(localized: "chore.intro.note"),
                cta: EmptyStateAction(title: String(localized: "chore.action.start")) {
                    guard environment.premiumGate.require(.create) else { return }
                    Task { await model.start() }
                }
            )
        }
        .padding(.top, CorbieSpacing.xxl)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func builder(_ model: ChoresViewModel) -> some View {
        if let set = model.openSet {
            ChoreListBuilderView(model: builderModel(set, in: model))
                .id(set.id)
        }
    }

    @ViewBuilder private func rating(_ model: ChoresViewModel) -> some View {
        if let set = model.openSet {
            ChoreRatingView(model: ratingModel(set, in: model))
                .id(set.id)
        }
    }

    private func waiting(_ model: ChoresViewModel) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "chore.waiting.title"),
                            environment.partnerName
                        )
                    )
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("chore.waiting.note")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            }
            if environment.isPaired {
                SecondaryButton(title: String(localized: "chore.action.nudge")) {
                    nudge(model)
                }
                .disabled(model.canNudge == false)
            }
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.m)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func ready(_ model: ChoresViewModel) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            Card(isHighlighted: true) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Text("chore.ready.title")
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                    Text("chore.ready.note")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            }
            PrimaryButton(title: String(localized: "chore.action.reveal")) {
                Task { await model.reveal() }
            }
            .disabled(model.isWorking)
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.m)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func reveal(_ model: ChoresViewModel) -> some View {
        if let set = model.openSet {
            ChoreRevealView(model: revealModel(set, in: model))
                .id(set.id)
        }
    }

    @ViewBuilder private func done(_ model: ChoresViewModel, appliedAt: Date) -> some View {
        if let set = model.lastAppliedSet {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text("chore.applied.title")
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "chore.state.applied"),
                                copy.month(appliedAt)
                            )
                        )
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                    }
                    ChoreSharesView(lists: shares(of: set))
                    if model.state == .needsResplit(appliedAt) {
                        Text("chore.state.resplit")
                            .corbieCaption()
                            .foregroundStyle(palette.text2)
                    }
                    PrimaryButton(title: String(localized: "chore.action.resplit")) {
                        guard environment.premiumGate.require(.create) else { return }
                        Task { await model.resplit() }
                    }
                    .disabled(model.isWorking)
                    NavigationLink {
                        ChoreHistoryView()
                    } label: {
                        Text("chore.action.history")
                            .corbieMono()
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, CorbieSpacing.l)
                .padding(.vertical, CorbieSpacing.m)
            }
        }
    }

    private func shares(of set: ChoreSetDTO) -> [ChoreShare] {
        ChoreSplitPresentation(
            set: set,
            viewerMemberId: environment.currentMember?.id,
            partnerMemberId: environment.partner?.id,
            partnerName: environment.partnerName,
            copy: copy
        ).lists
    }

    private func nudge(_ model: ChoresViewModel) {
        guard model.nudge() else { return }
        environment.toasts.show(
            message: String.localizedStringWithFormat(
                String(localized: "chore.nudge.sent"),
                environment.partnerName
            )
        )
    }

    private var context: ChoresContext {
        ChoresContext(
            spaceId: environment.space?.id,
            memberId: environment.currentMember?.id,
            partnerId: environment.partner?.id,
            partnerName: environment.partnerName,
            prefs: environment.currentMember?.notificationPrefs ?? .allEnabled
        )
    }

    private func start() async {
        let created = model ?? makeModel()
        model = created
        await created.apply(context)
    }

    private func makeModel() -> ChoresViewModel {
        let created = ChoresViewModel(
            repository: environment.repositories.chores,
            analytics: environment.analytics
        )
        created.onError = { error in
            environment.report(error)
        }
        return created
    }

    private func builderModel(_ set: ChoreSetDTO, in model: ChoresViewModel) -> ChoreListBuilderViewModel {
        let created = ChoreListBuilderViewModel(
            set: set,
            repository: environment.repositories.chores,
            memberId: environment.currentMember?.id,
            analytics: environment.analytics
        )
        created.onError = { environment.report($0) }
        created.onChanged = { model.replace($0) }
        return created
    }

    private func ratingModel(_ set: ChoreSetDTO, in model: ChoresViewModel) -> ChoreRatingViewModel {
        let created = ChoreRatingViewModel(
            set: set,
            repository: environment.repositories.chores,
            memberId: environment.currentMember?.id,
            analytics: environment.analytics
        )
        created.onError = { environment.report($0) }
        created.onChanged = { model.replace($0) }
        return created
    }

    private func revealModel(_ set: ChoreSetDTO, in model: ChoresViewModel) -> ChoreRevealViewModel {
        let created = ChoreRevealViewModel(
            set: set,
            repository: environment.repositories.chores,
            context: context,
            analytics: environment.analytics
        )
        created.onError = { environment.report($0) }
        created.onChanged = { model.replace($0) }
        return created
    }
}

struct ChoreFlowSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ChoresView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.action.done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChoresView()
    }
    .environment(AppState())
    .environment(AppEnvironment.previewSignedIn())
}
#endif
