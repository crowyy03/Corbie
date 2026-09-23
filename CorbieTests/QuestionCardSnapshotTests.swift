import CorbieCore
import SwiftUI
import XCTest
@testable import Corbie

@MainActor
final class QuestionCardSnapshotTests: XCTestCase {
    private let screenWidth: CGFloat = 393
    private let theme = ThemeSettings.firstLaunch.lightTheme
    private let samples: [(id: String, language: String)] = [
        ("q0131", "de"),
        ("q0439", "de"),
        ("q0639", "de"),
        ("q0847", "de"),
        ("q0102", "en"),
    ]

    func testTheTodayCardRendersTheLongestGermanQuestionsAndAShortEnglishOne() throws {
        for sample in samples {
            let locale = Locale(identifier: sample.language)
            let question = DailyQuestionDTO(id: UUID(), questionId: sample.id)
            let text = try XCTUnwrap(QuestionCopy(locale: locale).text(of: question), "\(sample.id) has no \(sample.language) text")
            let card = TodayQuestionCardStill(text: text, locale: locale)
            let name = "question_card_\(sample.id)_\(sample.language)"
            let regular = try render(card, dynamicTypeSize: .large, name: name)
            let largest = try render(card, dynamicTypeSize: .xxxLarge, name: name + "_xxxl")
            XCTAssertGreaterThan(largest.size.height, regular.size.height, "\(name) did not grow at xxxLarge")
        }
    }

    private func render(_ card: TodayQuestionCardStill, dynamicTypeSize: DynamicTypeSize, name: String) throws -> UIImage {
        let themed = card
            .frame(width: screenWidth)
            .background(theme.palette.bg)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .corbieTheme(theme)
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
        let renderer = ImageRenderer(content: themed)
        renderer.proposedSize = ProposedViewSize(width: screenWidth, height: nil)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        XCTAssertEqual(image.size.width, screenWidth, accuracy: 1, "\(name) is not as wide as the phone")
        XCTAssertGreaterThan(image.size.height, 0, "\(name) rendered with no height")
        guard let directory = ProcessInfo.processInfo.environment["CORBIE_SNAPSHOT_DIR"], directory.isEmpty == false else {
            return image
        }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let png = try XCTUnwrap(image.pngData(), "\(name) has no PNG data")
        try png.write(to: folder.appendingPathComponent(name + ".png"))
        return image
    }
}

private struct TodayQuestionCardStill: View {
    @Environment(\.palette) private var palette

    let text: String
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            SectionCaps(text: localized("today.block.question"))
            Card {
                TodayQuestionFull(
                    text: text,
                    status: .columns([
                        TodayQuestionColumn(line: localized("question.status.you.writing"), answered: false, color: palette.text2),
                        TodayQuestionColumn(
                            line: String(format: localized("question.status.writing"), locale: locale, "Alex"),
                            answered: false,
                            color: palette.text2
                        ),
                    ]),
                    callToAction: localized("question.action.answer"),
                    answer: {}
                )
            }
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.m)
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }
}
