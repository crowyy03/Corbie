import CorbieCore
import SwiftUI

struct TaskSubtitleFormatter {
    private static let separator = " · "

    let relativeDates: RelativeDateText

    init(locale: Locale = .current, calendar: Calendar = .current) {
        relativeDates = RelativeDateText(locale: locale, calendar: calendar)
    }

    func text(for task: TaskDTO, viewerMemberId: UUID?, partnerName: String?, now: Date) -> String {
        let subtitle = relativeDates.subtitle(
            for: task,
            viewerMemberId: viewerMemberId,
            partnerName: partnerName,
            now: now
        )
        return joined([phrase(subtitle), dueSuffix(dueText: subtitle.dueText, isOverdue: subtitle.isOverdue)])
    }

    func text(for item: TaskListItem, viewerMemberId: UUID?, partnerName: String?, now: Date) -> String {
        switch item {
        case let .task(task):
            return text(for: task, viewerMemberId: viewerMemberId, partnerName: partnerName, now: now)
        case let .goalStep(step):
            return joined([goalPhrase(step.goalTitle), stepDueSuffix(step, now: now)])
        }
    }

    private func stepDueSuffix(_ step: UnifiedTask, now: Date) -> String? {
        guard let dueAt = step.dueAt else { return nil }
        let daysAway = relativeDates.calendar.daysAway(from: now, to: dueAt) ?? 0
        return dueSuffix(
            dueText: relativeDates.dueText(for: dueAt, now: now),
            isOverdue: step.isDone == false && daysAway < 0
        )
    }

    private func goalPhrase(_ goalTitle: String?) -> String? {
        guard let goalTitle else { return nil }
        return String(format: String(localized: "tasks.row.subtitle.fromgoal"), goalTitle)
    }

    private func dueSuffix(dueText: String?, isOverdue: Bool) -> String? {
        guard let dueText else { return nil }
        let format = isOverdue
            ? String(localized: "tasks.row.due.past")
            : String(localized: "tasks.row.due")
        return String(format: format, dueText)
    }

    private func joined(_ parts: [String?]) -> String {
        parts
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
            .joined(separator: TaskSubtitleFormatter.separator)
    }

    private func phrase(_ subtitle: TaskSubtitle) -> String {
        let format: String
        switch subtitle.action {
        case .took:
            format = String(localized: "tasks.row.subtitle.took")
        case .set:
            format = String(localized: "tasks.row.subtitle.set")
        case .done:
            format = String(localized: "tasks.row.subtitle.done")
        case .free:
            return String(localized: "tasks.row.subtitle.free")
        }
        return String(format: format, name(of: subtitle.who), subtitle.relativeDay ?? "")
    }

    private func name(of who: TaskSubtitleActor) -> String {
        switch who {
        case .you:
            return String(localized: "member.name.you")
        case let .partner(name):
            return name ?? String(localized: "member.name.partner")
        case .nobody:
            return String(localized: "member.name.unknown")
        }
    }
}

struct TaskRow: View {
    let title: String
    let subtitle: String
    let dotColor: Color
    let placeName: String?
    let isDone: Bool
    let tick: (() -> Void)?
    let take: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        dotColor: Color,
        placeName: String? = nil,
        isDone: Bool = false,
        tick: (() -> Void)? = nil,
        take: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.dotColor = dotColor
        self.placeName = placeName
        self.isDone = isDone
        self.tick = tick
        self.take = take
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                if let tick {
                    TickButton(title: title, isDone: isDone, action: tick)
                }
                MemberDot(color: dotColor)
                    .padding(.top, tick == nil ? CorbieSpacing.xxs : CorbieSpacing.s)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .strikethrough(isDone, color: CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                    if subtitle.isEmpty == false {
                        Text(subtitle)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .multilineTextAlignment(.leading)
                    }
                    if let placeName {
                        PlaceChip(name: placeName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if let take {
                    TakeButton(title: title, action: take)
                }
            }
            .opacity(isDone ? 0.5 : 1)
        }
    }
}

private struct PlaceChip: View {
    let name: String

    var body: some View {
        HStack(spacing: CorbieSpacing.xxs) {
            Image(systemName: "mappin")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(name)
                .corbieMono()
        }
        .foregroundStyle(CorbieColorPalette.text2)
        .padding(.horizontal, CorbieSpacing.xs)
        .padding(.vertical, CorbieSpacing.xxs)
        .background(Capsule(style: .continuous).fill(CorbieColorPalette.elevated))
        .accessibilityElement(children: .combine)
    }
}

private struct TickButton: View {
    let title: String
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isDone ? CorbieColorPalette.ice : CorbieColorPalette.text2)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(String(localized: isDone ? "tasks.item.checked" : "tasks.item.unchecked")))
    }
}

private struct TakeButton: View {
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

#if DEBUG
private struct TaskRowGallery: View {
    private let now = Date()
    private let formatter = TaskSubtitleFormatter()
    private let mine = TaskDTO(
        id: UUID(),
        title: "Book the vet",
        assigneeMemberId: UUID(),
        dueAt: Date().addingTimeInterval(60 * 60 * 48),
        takenAt: Date().addingTimeInterval(-60 * 60 * 24),
        createdAt: Date().addingTimeInterval(-60 * 60 * 30)
    )
    private let free = TaskDTO(
        id: UUID(),
        title: "Buy milk",
        dueAt: Date().addingTimeInterval(-60 * 60 * 24),
        createdAt: Date().addingTimeInterval(-60 * 60 * 72)
    )
    private let placed = TaskDTO(
        id: UUID(),
        title: "Time Out Market",
        placeName: "Time Out Market",
        address: "Av. 24 de Julho, Lisbon",
        lat: 38.7067,
        lon: -9.1459
    )

    var body: some View {
        VStack(spacing: CorbieSpacing.s) {
            TaskRow(
                title: mine.title,
                subtitle: formatter.text(for: mine, viewerMemberId: mine.assigneeMemberId, partnerName: nil, now: now),
                dotColor: MemberColorKey.p1.color
            )
            TaskRow(
                title: free.title,
                subtitle: formatter.text(for: free, viewerMemberId: nil, partnerName: "Sofia", now: now),
                dotColor: CorbieColorPalette.text2,
                take: {}
            )
            TaskRow(
                title: placed.title,
                subtitle: "in Shopping",
                dotColor: MemberColorKey.p2.color,
                placeName: placed.placeName,
                isDone: true,
                tick: {}
            )
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CorbieColorPalette.bg)
    }
}

#Preview {
    TaskRowGallery()
}
#endif
