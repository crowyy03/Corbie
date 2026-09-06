import CorbieCore
import SwiftUI

struct TodayEntryRow: View {
    let entry: TodayEntry
    let dotColor: Color
    let time: String
    let fromPlan: String?
    let checkboxLabel: String
    let take: (() -> Void)?
    let toggle: (() -> Void)?
    let open: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                MemberDot(color: dotColor)
                    .padding(.top, CorbieSpacing.xs)
                Button(action: open) {
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(entry.title)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                            .strikethrough(entry.isDone)
                            .multilineTextAlignment(.leading)
                        Text(caption)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .accessibilityLabel(Text(entry.title))
                .accessibilityValue(Text(caption))
                if let take {
                    TakeButton(title: entry.title, action: take)
                        .padding(.top, CorbieSpacing.xxs)
                }
                if let toggle {
                    checkbox(toggle)
                }
            }
        }
    }

    private var caption: String {
        guard let fromPlan else { return time }
        return time + " · " + fromPlan
    }

    private func checkbox(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: CorbieSpacing.l))
                .foregroundStyle(entry.isDone ? CorbieColorPalette.ice : CorbieColorPalette.text2)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(checkboxLabel))
        .accessibilityValue(Text(entry.isDone ? "tasks.item.checked" : "tasks.item.unchecked"))
    }
}

struct TodayFreeTaskRow: View {
    let title: String
    let take: () -> Void
    let open: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: CorbieSpacing.s) {
                MemberDot(color: CorbieColorPalette.text2)
                Button(action: open) {
                    Text(title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                TakeButton(title: title, action: take)
            }
        }
    }
}

struct TodayDateRow: View {
    let title: String
    let caption: String
    let giftLine: String?
    let dotColor: Color
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Card {
                HStack(alignment: .top, spacing: CorbieSpacing.s) {
                    MemberDot(color: dotColor)
                        .padding(.top, CorbieSpacing.xs)
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(title)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                            .multilineTextAlignment(.leading)
                        Text(giftLine ?? caption)
                            .corbieMono()
                            .foregroundStyle(giftLine == nil ? CorbieColorPalette.text2 : CorbieColorPalette.ice)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(giftLine ?? caption))
    }
}

struct TodayWaitingRow: View {
    let title: String
    let caption: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Card(showsChromeGradient: true) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                    Text(caption)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(caption))
    }
}

struct TodayPlansCarousel: View {
    let plans: [TodayPlan]
    let open: (TodayPlan) -> Void
    let add: () -> Void

    private var showsSteps: Bool {
        plans.contains { $0.stepCount > 0 }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: CorbieSpacing.m) {
                if plans.isEmpty {
                    AddPlanCard(action: add)
                }
                ForEach(plans) { plan in
                    CompactPlanCard(plan: plan, showsSteps: showsSteps) { open(plan) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

struct AddPlanCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    Image(systemName: "plus")
                        .font(.system(size: CorbieSpacing.l))
                        .foregroundStyle(CorbieColorPalette.ice)
                        .accessibilityHidden(true)
                    Text("plans.empty.action")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(width: CompactPlanCard.width)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
