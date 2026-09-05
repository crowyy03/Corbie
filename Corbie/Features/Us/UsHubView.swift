import CorbieCore
import SwiftUI

struct UsHubView: View {
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
                    destination: CapsulesView()
                )
                UsTile(
                    systemImage: "hand.raised",
                    title: String(localized: "us.hub.votes"),
                    line: String(localized: "us.tile.votes.line"),
                    countText: String(localized: "us.tile.votes.count \(model.voteCount)"),
                    destination: VotesView()
                )
                UsTile(
                    systemImage: "person.crop.circle",
                    title: String(localized: "us.hub.people"),
                    line: String(localized: "us.tile.people.line"),
                    countText: String(localized: "us.tile.people.count \(model.peopleCount)"),
                    destination: PeopleEntryView(count: model.peopleCount)
                )
                settings
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .background(CorbieColorPalette.bg)
        .task {
            await model.load(environment)
        }
        .onChange(of: environment.premiumGate.pendingPaywall?.id) { _, request in
            guard request != nil else { return }
            appState.isUsHubPresented = false
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("us.hub.header")
                .corbieScreenTitle()
                .foregroundStyle(CorbieColorPalette.text)
            Spacer(minLength: CorbieSpacing.s)
            UsPill(
                colorA: environment.memberColor(id: environment.currentMember?.id),
                colorB: environment.memberColor(id: environment.partner?.id)
            )
        }
        .padding(.top, CorbieSpacing.s)
    }

    private var counters: some View {
        Card(showsChromeGradient: true) {
            HStack(alignment: .top, spacing: CorbieSpacing.m) {
                counterColumn(
                    value: model.counters.daysTogether,
                    caption: String(localized: "us.counters.days")
                )
                Rectangle()
                    .fill(CorbieColorPalette.border)
                    .frame(width: CorbieMetrics.hairline)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                counterColumn(
                    value: model.counters.next?.daysAway,
                    caption: model.counters.next?.label.text ?? String(localized: "us.counters.empty")
                )
            }
            .frame(minHeight: CorbieMetrics.controlHeight)
        }
    }

    private func counterColumn(value: Int?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(value.map { $0.formatted() } ?? "-")
                .corbieCounter()
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(caption)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var settings: some View {
        Card {
            HStack(spacing: CorbieSpacing.s) {
                Image(systemName: "gearshape")
                    .foregroundStyle(CorbieColorPalette.text2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text("us.hub.settings")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text("us.settings.note")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UsTile<Destination: View>: View {
    let systemImage: String
    let title: String
    let line: String
    let countText: String
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    HStack(spacing: CorbieSpacing.xs) {
                        Image(systemName: systemImage)
                            .foregroundStyle(CorbieColorPalette.ice)
                            .accessibilityHidden(true)
                        Text(title)
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(CorbieColorPalette.text)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(CorbieColorPalette.text2)
                            .accessibilityHidden(true)
                    }
                    Text(line)
                        .corbieCaption()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                    Text(countText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack {
        UsHubView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
