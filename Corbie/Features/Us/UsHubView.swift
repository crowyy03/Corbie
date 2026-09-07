import CorbieCore
import SwiftUI

struct UsHubView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var model = UsHubViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                header
                counters
                UsTile(
                    systemImage: "envelope",
                    title: String(localized: "us.hub.capsules"),
                    line: String(localized: "us.tile.capsules.line"),
                    countText: String(localized: "us.tile.capsules.count \(model.capsuleCount)"),
                    destination: .capsules(startsWithEditor: false)
                )
                UsTile(
                    systemImage: "hand.raised",
                    title: String(localized: "us.hub.votes"),
                    line: String(localized: "us.tile.votes.line"),
                    countText: String(localized: "us.tile.votes.count \(model.voteCount)"),
                    destination: .votes(startsWithEditor: false)
                )
                UsTile(
                    systemImage: "person.crop.circle",
                    title: String(localized: "us.hub.people"),
                    line: String(localized: "us.tile.people.line"),
                    countText: String(localized: "us.tile.people.count \(model.peopleCount)"),
                    destination: .people
                )
                settings
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .background(palette.bg)
        .task {
            await model.load(environment)
        }
        .task {
            await markVisit()
        }
        .onChange(of: environment.premiumGate.pendingPaywall?.id) { _, request in
            guard request != nil else { return }
            appState.isUsHubPresented = false
        }
    }

    private func markVisit() async {
        guard let member = environment.currentMember else { return }
        do {
            environment.apply(member: try await environment.usBadge.markVisited(memberId: member.id))
        } catch {
            environment.report(error)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("us.hub.header")
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
            Spacer(minLength: CorbieSpacing.s)
            UsPill(
                slotA: environment.memberSlot(id: environment.currentMember?.id),
                slotB: environment.memberSlot(id: environment.partner?.id)
            )
        }
        .padding(.top, CorbieSpacing.s)
    }

    private var nextDateCaption: String {
        guard let next = model.counters.next else { return String(localized: "us.counters.empty") }
        return ImportantDateText.countdown(
            kind: next.kind,
            ordinal: next.ordinal,
            title: next.personName
        )
    }

    private var counters: some View {
        Card(isHighlighted: true) {
            HStack(alignment: .top, spacing: CorbieSpacing.m) {
                counterColumn(
                    value: model.counters.daysTogether,
                    caption: String(localized: "us.counters.days")
                )
                Rectangle()
                    .fill(palette.border)
                    .frame(width: CorbieMetrics.hairline)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                counterColumn(
                    value: model.counters.next?.daysAway,
                    caption: nextDateCaption
                )
            }
            .frame(minHeight: CorbieMetrics.controlHeight)
        }
    }

    private func counterColumn(value: Int?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(value.map { $0.formatted() } ?? "-")
                .corbieCounter()
                .foregroundStyle(value == nil ? palette.text2 : palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(caption)
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var settings: some View {
        NavigationLink(value: UsDestination.settings) {
            Card {
                HStack(spacing: CorbieSpacing.s) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(palette.text2)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text("us.hub.settings")
                            .corbieBody()
                            .foregroundStyle(palette.text)
                        Text("us.settings.note")
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(palette.text2)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct UsTile: View {
    @Environment(\.palette) private var palette

    let systemImage: String
    let title: String
    let line: String
    let countText: String
    let destination: UsDestination

    var body: some View {
        NavigationLink(value: destination) {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    HStack(spacing: CorbieSpacing.xs) {
                        Image(systemName: systemImage)
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                        Text(title)
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(palette.text2)
                            .accessibilityHidden(true)
                    }
                    Text(line)
                        .corbieCaption()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.leading)
                    Text(countText)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        UsHubView()
            .usDestinations()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
