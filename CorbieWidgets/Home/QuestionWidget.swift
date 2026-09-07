import CorbieCore
import SwiftUI
import WidgetKit

struct QuestionEntry: TimelineEntry {
    let date: Date
    let snapshot: QuestionSnapshot

    static let placeholder = QuestionEntry(date: Date(), snapshot: QuestionSnapshot.blank(isPremium: true))

    static func load(now: Date, provider: WidgetDataProvider) async -> QuestionEntry {
        let snapshot = (try? await provider.question(now: now)) ?? QuestionSnapshot.blank(isPremium: true)
        return QuestionEntry(date: now, snapshot: snapshot)
    }
}

struct QuestionSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.questionSmall,
            provider: CorbieTimelineProvider(placeholderEntry: QuestionEntry.placeholder) { now in
                await QuestionEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            QuestionSmallWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.question.title"))
        .description(Text("widget.question.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct QuestionMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.questionMedium,
            provider: CorbieTimelineProvider(placeholderEntry: QuestionEntry.placeholder) { now in
                await QuestionEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            QuestionMediumWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.question.medium.title"))
        .description(Text("widget.question.medium.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct QuestionSmallWidgetView: View {
    let entry: QuestionEntry

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if let text = entry.snapshot.text {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    WidgetHeading(text: String(localized: "widget.question.heading"))
                    Text(text)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    WidgetQuestionDots(snapshot: entry.snapshot)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.question.url)
            } else {
                WidgetEmptyState(title: "widget.question.empty", note: "widget.question.empty.note")
                    .widgetURL(CorbieRoute.question.url)
            }
        }
    }
}

struct QuestionMediumWidgetView: View {
    let entry: QuestionEntry

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if let text = entry.snapshot.text {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    WidgetHeading(text: String(localized: "widget.question.heading"))
                    Text(text)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    HStack(alignment: .top, spacing: CorbieSpacing.m) {
                        WidgetQuestionStatus(member: entry.snapshot.viewer, isViewer: true)
                        WidgetQuestionStatus(member: entry.snapshot.partner, isViewer: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.question.url)
            } else {
                WidgetEmptyState(title: "widget.question.empty", note: "widget.question.empty.note")
                    .widgetURL(CorbieRoute.question.url)
            }
        }
    }
}

struct WidgetQuestionDots: View {
    let snapshot: QuestionSnapshot

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            dot(snapshot.viewer)
            if let partner = snapshot.partner {
                dot(partner)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    private var spoken: String {
        [
            WidgetQuestionText.line(snapshot.viewer, isViewer: true),
            WidgetQuestionText.line(snapshot.partner, isViewer: false),
        ].joined(separator: ", ")
    }

    @ViewBuilder private func dot(_ member: WidgetQuestionMember?) -> some View {
        let color = member?.colorKey.map { MemberColor(key: $0).color } ?? CorbieColorPalette.text2
        if member?.hasAnswered == true {
            Circle()
                .fill(color)
                .frame(width: CorbieMetrics.memberDotSize, height: CorbieMetrics.memberDotSize)
        } else {
            Circle()
                .strokeBorder(color.opacity(0.5), lineWidth: CorbieMetrics.hairline)
                .frame(width: CorbieMetrics.memberDotSize, height: CorbieMetrics.memberDotSize)
        }
    }
}

struct WidgetQuestionStatus: View {
    let member: WidgetQuestionMember?
    let isViewer: Bool

    var body: some View {
        Text(WidgetQuestionText.line(member, isViewer: isViewer))
            .corbieMono()
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var color: Color {
        guard member?.hasAnswered == true, let colorKey = member?.colorKey else {
            return CorbieColorPalette.text2
        }
        return MemberColor(key: colorKey).color
    }
}

enum WidgetQuestionText {
    static func line(_ member: WidgetQuestionMember?, isViewer: Bool) -> String {
        let answered = member?.hasAnswered == true
        if isViewer {
            return String(localized: answered ? "question.status.you.answered" : "question.status.you.writing")
        }
        let given = member?.name ?? ""
        let name = given.isEmpty ? String(localized: "member.name.partner") : given
        let key: String.LocalizationValue = answered ? "question.status.answered" : "question.status.writing"
        return String.localizedStringWithFormat(String(localized: key), name)
    }
}

#if DEBUG
#Preview("Question small", as: .systemSmall) {
    QuestionSmallWidget()
} timeline: {
    QuestionEntry(date: Date(), snapshot: WidgetPreviewData.question(viewerAnswered: true))
    QuestionEntry.placeholder
    QuestionEntry(date: Date(), snapshot: QuestionSnapshot.blank(isPremium: false))
}

#Preview("Question medium", as: .systemMedium) {
    QuestionMediumWidget()
} timeline: {
    QuestionEntry(date: Date(), snapshot: WidgetPreviewData.question(viewerAnswered: true))
    QuestionEntry(date: Date(), snapshot: WidgetPreviewData.question(viewerAnswered: false))
}
#endif
