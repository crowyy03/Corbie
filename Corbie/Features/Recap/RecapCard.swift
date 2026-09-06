import CorbieCore
import SwiftUI

struct RecapCard: View {
    let summary: RecapSummary
    let open: () -> Void

    private let presentation = RecapPresentation()

    var body: some View {
        Button(action: open) {
            Card(showsChromeGradient: true) {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    SectionCaps(text: String(localized: "recap.title"))
                    columns
                    goals
                    comingUp
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("recap.open"))
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: CorbieSpacing.l) {
            ForEach(summary.members) { member in
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(spacing: CorbieSpacing.xxs) {
                        MemberDot(color: MemberColor(key: member.colorKey).color)
                        Text(member.name ?? String(localized: "member.name.partner"))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                    Text(presentation.count(member.tasksDone))
                        .corbieCounter()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text("recap.tasks")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var goals: some View {
        if summary.goals.isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                ForEach(summary.goals) { move in
                    Text(presentation.goalLine(move))
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    @ViewBuilder private var comingUp: some View {
        if summary.comingUp.isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                SectionCaps(text: String(localized: "today.block.comingup"))
                ForEach(summary.comingUp) { item in
                    Text(
                        presentation.upcomingTitle(item)
                            + " · "
                            + presentation.upcomingCaption(item, now: summary.week.end)
                    )
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .multilineTextAlignment(.leading)
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            if let days = summary.daysTogether {
                Text(presentation.count(days) + " " + String(localized: "today.header.days"))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
            if let milestone = summary.milestone {
                Text(presentation.milestoneLine(milestone))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.ice)
            }
        }
    }
}

#if DEBUG
private struct RecapCardGallery: View {
    private let calendar = Calendar.current

    var body: some View {
        let week = RecapSchedule.week(closing: Date(), calendar: calendar)
        return RecapCard(
            summary: RecapSummary(
                week: week,
                members: [
                    RecapMemberTally(
                        memberId: UUID(),
                        name: PreviewNames.member,
                        colorKey: MemberColorKey.defaultA.rawValue,
                        tasksDone: 12,
                        wishesAdded: 2
                    ),
                    RecapMemberTally(
                        memberId: UUID(),
                        name: PreviewNames.partner,
                        colorKey: MemberColorKey.defaultB.rawValue,
                        tasksDone: 7,
                        wishesAdded: 0
                    )
                ],
                goals: [
                    RecapGoalMove(
                        goalId: UUID(),
                        title: "Japan",
                        delta: 300,
                        currency: "EUR",
                        progress: 0.48
                    )
                ],
                comingUp: [
                    RecapUpcoming(
                        id: "event.1",
                        kind: .event,
                        name: "Dinner with Anna",
                        date: week.end,
                        eventId: UUID()
                    )
                ],
                daysTogether: 1250,
                milestone: RecapMilestone(days: 1255, date: week.end)
            ),
            open: {}
        )
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CorbieColorPalette.bg)
    }
}

#Preview("Recap light") {
    RecapCardGallery().preferredColorScheme(.light)
}

#Preview("Recap dark") {
    RecapCardGallery().preferredColorScheme(.dark)
}
#endif
