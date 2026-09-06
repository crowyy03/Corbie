import CorbieCore
import SwiftUI

struct TodayEntryRow: View {
    let entry: TodayEntry
    let dotColor: Color
    let time: String
    let fromGoal: String?
    let checkboxLabel: String
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
                if let toggle {
                    checkbox(toggle)
                }
            }
        }
    }

    private var caption: String {
        guard let fromGoal else { return time }
        return time + " · " + fromGoal
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
                TodayTakeButton(title: title, action: take)
            }
        }
    }
}

struct TodayTakeButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("tasks.action.take")
                .corbieCaption()
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.accentInk)
                .padding(.horizontal, CorbieSpacing.s)
                .frame(minHeight: CorbieMetrics.chipHeight)
                .background(Capsule(style: .continuous).fill(CorbieColorPalette.ice))
        }
        .buttonStyle(.plain)
        .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(String(format: String(localized: "tasks.action.take.accessibility"), title)))
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

struct TodayGoalCard: View {
    let title: String
    let amount: String
    let progress: Double
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    Text(title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                    ProgressBar(value: progress)
                    Text(amount)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(amount))
    }
}
