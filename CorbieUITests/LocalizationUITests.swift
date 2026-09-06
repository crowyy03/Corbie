import XCTest

final class LocalizationUITests: XCTestCase {
    private let screenshotDirectory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishTabsFitTheTabBar() throws {
        try run("en", "en_US")
    }

    func testGermanTabsFitTheTabBar() throws {
        try run("de", "de_DE")
    }

    func testSpanishTabsFitTheTabBar() throws {
        try run("es", "es_ES")
    }

    func testFrenchTabsFitTheTabBar() throws {
        try run("fr", "fr_FR")
    }

    func testItalianTabsFitTheTabBar() throws {
        try run("it", "it_IT")
    }

    private func run(_ language: String, _ locale: String) throws {
        try XCTSkipUnless(
            QACatalog.languages.contains(language),
            "the app does not ship \(language)"
        )
        let untranslated = QATab.allCases
            .map(\.titleKey)
            .filter { QACatalog.has($0, language: language) == false }
        try XCTSkipIf(
            untranslated.isEmpty == false,
            "\(language) has no value for \(untranslated.joined(separator: ", ")), "
                + "so the tab bar shows the raw key (see docs/KNOWN_ISSUES.md)"
        )
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-corbie-erase-everything",
        ]
        app.launch()

        passOnboarding(app, language)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 40), language)
        XCTAssertEqual(tabBar.buttons.count, QATab.allCases.count, language)

        for tab in QATab.allCases {
            let title = QACatalog.text(tab.titleKey, language: language)
            let button = tabBar.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(language): \(title)")
            button.tap()
            save(app, language, "tab\(tab.rawValue)_\(language)")
        }
    }

    private func passOnboarding(_ app: XCUIApplication, _ language: String) {
        let debugSignIn = app.buttons[QACatalog.text("onboarding.debug.signin", language: language)]
        guard debugSignIn.waitForExistence(timeout: 30) else { return }
        save(app, language, "onboarding_intro_\(language)")
        UITestFlows.waitUntilHittable(debugSignIn)
        debugSignIn.tap()

        let continueButton = app.buttons[QACatalog.text("onboarding.profile.continue", language: language)]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 40), language)
        save(app, language, "onboarding_profile_\(language)")
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons[QACatalog.text("pairing.invite.later", language: language)]
        XCTAssertTrue(later.waitForExistence(timeout: 60), language)
        save(app, language, "onboarding_invite_\(language)")
        later.tap()
    }

    private func save(_ app: XCUIApplication, _ language: String, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let screenshotDirectory else { return }
        let folder = URL(fileURLWithPath: screenshotDirectory).appendingPathComponent(language)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
