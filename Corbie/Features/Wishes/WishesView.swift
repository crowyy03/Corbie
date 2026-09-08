import Combine
import CorbieCore
import SwiftUI
import UIKit

struct WishesView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var viewModel = WishesViewModel()
    @State private var network = WishesNetworkMonitor()
    @State private var editor: WishEditorRequest?

    var body: some View {
        VStack(spacing: 0) {
            chips
            content
        }
        .background(palette.bg.ignoresSafeArea())
        .screenHeader(String(localized: "tab.wishes.title")) {
            AddButton { startCreating(link: nil) }
            UsPillButton()
        }
        .sheet(item: $editor) { request in
            WishEditorView(request: request) {
                await viewModel.load()
            }
        }
        .task {
            network.start()
            consumeRoute()
            await reload()
        }
        .onDisappear {
            network.stop()
        }
        .onChange(of: environment.session) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: WidgetReloadRequest.notificationName)) { _ in
            Task { await viewModel.load() }
        }
        .onChange(of: appState.route) { _, _ in
            consumeRoute()
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CorbieSpacing.xs) {
                ForEach(viewModel.availableFilters, id: \.self) { filter in
                    Button {
                        viewModel.filter = filter
                    } label: {
                        Chip(
                            label: viewModel.label(for: filter),
                            count: viewModel.count(for: filter),
                            isSelected: viewModel.filter == filter,
                            tint: tint(for: filter)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CorbieSpacing.m)
            .padding(.bottom, CorbieSpacing.xs)
        }
    }

    private var content: some View {
        List {
            if viewModel.visibleActive.isEmpty {
                emptyState
                    .padding(.top, CorbieSpacing.xl)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(viewModel.visibleActive) { wish in
                row(wish)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await viewModel.markGifted(wish) }
                        } label: {
                            Label("wishes.action.gifted", systemImage: "gift")
                        }
                        .tint(palette.accent)
                        Button {
                            Task { await viewModel.delete(wish) }
                        } label: {
                            Label("wishes.action.delete", systemImage: "trash")
                        }
                        .tint(palette.warn)
                    }
            }
            if viewModel.visibleFulfilled.isEmpty == false {
                fulfilledSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.load()
        }
    }

    private var fulfilledSection: some View {
        Section {
            if viewModel.isFulfilledExpanded {
                ForEach(viewModel.visibleFulfilled) { wish in
                    row(wish)
                        .opacity(0.6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                Task { await viewModel.delete(wish) }
                            } label: {
                                Label("wishes.action.delete", systemImage: "trash")
                            }
                            .tint(palette.warn)
                        }
                }
            }
        } header: {
            Button {
                viewModel.isFulfilledExpanded.toggle()
            } label: {
                HStack(spacing: CorbieSpacing.xs) {
                    SectionCaps(text: String(localized: "wishes.section.fulfilled"))
                    Text(viewModel.visibleFulfilled.count.formatted())
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                    Spacer(minLength: 0)
                    Image(systemName: viewModel.isFulfilledExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(palette.text2)
                }
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(viewModel.isFulfilledExpanded ? [.isButton, .isSelected] : .isButton)
            .listRowInsets(EdgeInsets(top: 0, leading: CorbieSpacing.m, bottom: 0, trailing: CorbieSpacing.m))
        }
    }

    private func row(_ wish: WishDTO) -> some View {
        Button {
            startEditing(wish)
        } label: {
            WishCardView(
                wish: wish,
                approximate: viewModel.approximate(for: wish),
                ownerSlot: environment.memberSlot(id: wish.ownerMemberId),
                ownerName: environment.memberName(id: wish.ownerMemberId)
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: CorbieSpacing.xxs,
                leading: CorbieSpacing.m,
                bottom: CorbieSpacing.xxs,
                trailing: CorbieSpacing.m
            )
        )
    }

    private var emptyState: some View {
        VStack(spacing: CorbieSpacing.m) {
            EmptyState(
                systemImage: "sparkles",
                title: String(localized: "wishes.empty.title"),
                monoNote: String(localized: "wishes.empty.note")
            )
            Button {
                pasteFromClipboard()
            } label: {
                Text("wishes.empty.paste")
                    .corbieMono()
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func tint(for filter: WishesFilter) -> MemberColorSlot? {
        switch filter {
        case .partner: return environment.memberSlot(id: environment.partner?.id)
        case .me: return environment.memberSlot(id: environment.currentMember?.id)
        case .all: return nil
        }
    }

    private func startCreating(link: String?) {
        guard environment.premiumGate.require(.create) else { return }
        editor = WishEditorRequest(wish: nil, link: link)
    }

    private func startEditing(_ wish: WishDTO) {
        guard environment.premiumGate.require(.edit) else { return }
        editor = WishEditorRequest(wish: wish, link: nil)
    }

    private func pasteFromClipboard() {
        let pasteboard = UIPasteboard.general
        let raw = pasteboard.url?.absoluteString ?? pasteboard.string ?? ""
        guard let url = LinkParser.normalize(raw) else {
            environment.toasts.show(message: String(localized: "wishes.paste.empty"))
            return
        }
        startCreating(link: url.absoluteString)
    }

    private func reload() async {
        viewModel.configure(environment)
        await viewModel.load()
        await viewModel.retryPendingParse(isOnline: network.isOnline)
    }

    private func consumeRoute() {
        guard appState.route == .wishes else { return }
        viewModel.resetFilter()
        appState.route = nil
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WishesView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
