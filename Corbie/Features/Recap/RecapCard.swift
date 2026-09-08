import CorbieCore
import SwiftUI

struct RecapCard: View {
    @Environment(\.palette) private var palette

    let summary: RecapSummary
    let open: () -> Void

    private let presentation = RecapPresentation()

    var body: some View {
        Button(action: open) {
            Card(isHighlighted: true) {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    SectionCaps(text: String(localized: "recap.title"))
                    columns
                    plans
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
                        MemberDot(slot: MemberColorSlot.stored(member.colorKey))
                        Text(member.name ?? String(localized: "member.name.partner"))
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                    Text(presentation.count(member.tasksDone))
                        .corbieCounter()
                        .foregroundStyle(palette.text)
                    Text("recap.tasks")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var plans: some View {
        if summary.plans.isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                ForEach(summary.plans) { move in
                    Text(presentation.planLine(move))
                        .corbieBody()
                        .foregroundStyle(palette.text)
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
                    .foregroundStyle(palette.text2)
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
                    .foregroundStyle(palette.text2)
            }
            if let milestone = summary.milestone {
                Text(presentation.milestoneLine(milestone))
                    .corbieMono()
                    .foregroundStyle(palette.accent)
            }
        }
    }
}

#if DEBUG
private struct RecapCardGallery: View {
    @Environment(\.palette) private var palette

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
                        colorKey: MemberColorSlot.creatorDefault.rawValue,
                        tasksDone: 12,
                        wishesAdded: 2
                    ),
                    RecapMemberTally(
                        memberId: UUID(),
                        name: PreviewNames.partner,
                        colorKey: MemberColorSlot.partnerDefault.rawValue,
                        tasksDone: 7,
                        wishesAdded: 0
                    )
                ],
                plans: [
                    RecapPlanMove(
                        planId: UUID(),
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
        .background(palette.bg)
    }
}

#Preview("Recap light") {
    RecapCardGallery().preferredColorScheme(.light)
}

#Preview("Recap dark") {
    RecapCardGallery().preferredColorScheme(.dark)
}
#endif
