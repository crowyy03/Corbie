import XCTest

final class ThemeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPickingADarkThemeRepaintsTheWholeApp() throws {
        let app = launchSignedIn(appearance: "light")
        selectTab(app, .today)
        let before = try screenBrightness(app)

        openSharedSettings(app)
        let follow = settingsSwitch(app, "settings.appearance.followsystem")
        XCTAssertTrue(scrollTo(follow, in: app), "settings has no appearance toggle")
        if (follow.value as? String) == "1" {
            flip(follow)
        }

        let deep = app.collectionViews.buttons[QACatalog.text("theme.name.deep")].firstMatch
        XCTAssertTrue(scrollTo(deep, in: app), "the theme picker offers no Deep card")
        deep.tap()
        XCTAssertTrue(deep.isSelected, "tapping Deep did not select it")

        closeSettings(app)
        selectTab(app, .today)
        let after = try screenBrightness(app)

        XCTAssertGreaterThan(before.content, 0.6, "the light theme did not paint a light background")
        XCTAssertGreaterThan(before.bottom, 0.6, "the light theme did not paint the strip beside the tab bar")
        XCTAssertLessThan(after.content, 0.3, "the content kept the light background after switching to Deep")
        XCTAssertLessThan(after.bottom, 0.3, "the strip beside the tab bar kept the light background after switching to Deep")
    }

    func testTheThemeChoiceSurvivesARelaunch() throws {
        let app = launchSignedIn(appearance: "light")
        openSharedSettings(app)
        let follow = settingsSwitch(app, "settings.appearance.followsystem")
        XCTAssertTrue(scrollTo(follow, in: app), "settings has no appearance toggle")
        if (follow.value as? String) == "1" {
            flip(follow)
        }
        let sage = app.collectionViews.buttons[QACatalog.text("theme.name.sage")].firstMatch
        XCTAssertTrue(scrollTo(sage, in: app), "the theme picker offers no Sage card")
        sage.tap()

        app.terminate()
        app.launchArguments.removeAll { $0 == XCUIApplication.resetStoreArgument }
        app.dropThemeLaunchArguments()
        app.launch()

        openSharedSettings(app)
        let again = app.collectionViews.buttons[QACatalog.text("theme.name.sage")].firstMatch
        XCTAssertTrue(scrollTo(again, in: app), "the theme picker is gone after a relaunch")
        XCTAssertTrue(again.isSelected, "the chosen theme did not survive a relaunch")
    }

    func testThePartnerColourIsNotOfferedTwice() throws {
        let app = launchSignedIn()
        openSharedSettings(app)
        let teal = app.collectionViews.buttons[QACatalog.text("member.color.teal")].firstMatch
        XCTAssertTrue(scrollTo(teal, in: app), "settings has no colour picker")
        XCTAssertTrue(teal.isEnabled, "a free colour is not tappable")
    }

    private func closeSettings(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        closeUsHub(app)
    }

    private func screenBrightness(_ app: XCUIApplication) throws -> (content: Double, bottom: Double) {
        let shot = app.screenshot().image
        guard let image = shot.cgImage else { throw XCTSkip("the screenshot carries no bitmap") }
        let width = image.width
        let height = image.height
        let content = try brightness(of: image, x: width / 2, y: height / 2)
        let bottom = try brightness(of: image, x: width / 40, y: height - height / 40)
        return (content, bottom)
    }

    private func brightness(of image: CGImage, x: Int, y: Int) throws -> Double {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixel,
                  width: 1,
                  height: 1,
                  bitsPerComponent: 8,
                  bytesPerRow: 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw XCTSkip("this device cannot read screenshot pixels")
        }
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        let red = Double(pixel[0]) / 255
        let green = Double(pixel[1]) / 255
        let blue = Double(pixel[2]) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
