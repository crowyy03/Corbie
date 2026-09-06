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
        var parts = [phrase(subtitle)]
        if let dueText = subtitle.dueText {
            let format = subtitle.isOverdue
                ? String(localized: "tasks.row.due.past")
                : String(localized: "tasks.row.due")
            parts.append(String(format: format, dueText))
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
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
    let task: TaskDTO
    let dotColor: Color
    let subtitle: String
    let take: (() -> Void)?

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                MemberDot(color: dotColor)
                    .padding(.top, CorbieSpacing.xxs)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(task.title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                if let take {
                    TakeButton(title: task.title, action: take)
                }
            }
        }
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

    var body: some View {
        VStack(spacing: CorbieSpacing.s) {
            TaskRow(
                task: mine,
                dotColor: MemberColorKey.p1.color,
                subtitle: formatter.text(for: mine, viewerMemberId: mine.assigneeMemberId, partnerName: nil, now: now),
                take: nil
            )
            TaskRow(
                task: free,
                dotColor: CorbieColorPalette.text2,
                subtitle: formatter.text(for: free, viewerMemberId: nil, partnerName: "Sofia", now: now),
                take: {}
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
