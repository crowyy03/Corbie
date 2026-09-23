import CorbieCore
import SwiftUI
import UIKit
import XCTest
@testable import Corbie

@MainActor
final class TodayQuestionTitleTests: XCTestCase {
    private let titleWidth: CGFloat = 393 - 2 * CorbieSpacing.l - 2 * CorbieSpacing.m

    func testNoQuestionIsCutAtAnyTextSizeOnA393PointPhone() {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        let bank = QuestionBank.bundled
        XCTAssertEqual(bank.entries.count, 1000)
        var cut: [String] = []
        for size in DynamicTypeSize.allCases where size >= .large {
            let floor = smallestSize(at: size)
            let limit = TodayQuestionTitle.lineLimit(for: size)
            var longest = 0
            for entry in bank.entries {
                for language in QuestionBankEntry.languages {
                    let lines = lineCount(entry.text(for: Locale(identifier: language)), size: floor, host: host)
                    longest = max(longest, lines)
                    if lines > limit {
                        cut.append("\(size) \(entry.id) \(language): \(lines) lines, limit \(limit)")
                    }
                }
            }
            print("question title at \(size): floor \(floor) pt, longest \(longest) lines, limit \(limit)")
        }
        XCTAssertEqual(cut, [])
    }

    func testTheFourLongestGermanQuestionsTakeThreeLinesAtTheSmallestSize() throws {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        let german = Locale(identifier: "de")
        for id in ["q0131", "q0439", "q0639", "q0847"] {
            let text = try XCTUnwrap(QuestionBank.bundled.entry(id: id)?.text(for: german), id)
            XCTAssertEqual(lineCount(text, size: smallestSize(at: .large), host: host), 3, id)
        }
    }

    private func smallestSize(at size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let title = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: CorbieFont.screenTitleSize, compatibleWith: traits)
        return title * TodayQuestionTitle.smallestScale
    }

    private func lineCount(_ text: String, size: CGFloat, host: UIHostingController<AnyView>) -> Int {
        host.rootView = AnyView(
            Text(text)
                .font(.system(size: size, weight: .bold, design: .default))
                .tracking(CorbieFont.screenTitleTracking * TodayQuestionTitle.smallestScale)
        )
        let height = host.sizeThatFits(in: CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height
        let lineHeight = UIFont.systemFont(ofSize: size, weight: .bold).lineHeight
        return Int((height / lineHeight).rounded())
    }
}
