import CorbieCore
import SwiftUI
import XCTest
@testable import Corbie

@MainActor
final class WishDesignSnapshotTests: XCTestCase {
    private let screen = WishPreviewSamples.screen

    func testTheCardRendersInEveryThemeAndState() throws {
        for theme in CorbieTheme.allCases {
            for state in WishPreviewState.allCases {
                let card = WishCardPreview(state: state)
                    .padding(.horizontal, CorbieSpacing.m)
                    .padding(.vertical, CorbieSpacing.xs)
                    .frame(width: screen.width)
                    .background(theme.palette.bg)
                try render(card, theme: theme, height: nil, name: "wish_card_\(theme.rawValue)_\(state.rawValue)")
            }
        }
    }

    func testTheDetailRendersInEveryThemeAndState() throws {
        for theme in CorbieTheme.allCases {
            for state in WishPreviewState.allCases {
                let detail = WishDetailStill(state: state)
                    .frame(width: screen.width, height: screen.height)
                try render(detail, theme: theme, height: screen.height, name: "wish_detail_\(theme.rawValue)_\(state.rawValue)")
            }
        }
    }

    private func render<Content: View>(_ content: Content, theme: CorbieTheme, height: CGFloat?, name: String) throws {
        let themed = content
            .corbieTheme(theme)
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
        let renderer = ImageRenderer(content: themed)
        renderer.proposedSize = ProposedViewSize(width: screen.width, height: height)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        XCTAssertEqual(image.size.width, screen.width, accuracy: 1, "\(name) is not as wide as the phone")
        XCTAssertGreaterThan(image.size.height, 0, "\(name) rendered with no height")
        if let height {
            XCTAssertEqual(image.size.height, height, accuracy: 1, "\(name) is not as tall as the phone")
        }
        guard let directory = ProcessInfo.processInfo.environment["CORBIE_SNAPSHOT_DIR"], directory.isEmpty == false else {
            return
        }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let png = try XCTUnwrap(image.pngData(), "\(name) has no PNG data")
        try png.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
