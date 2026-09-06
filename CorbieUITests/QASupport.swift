import XCTest

enum QARun {
    static var language: String {
        let value = ProcessInfo.processInfo.environment["CORBIE_UI_LANGUAGE"] ?? "en"
        return value.isEmpty ? "en" : value
    }

    static var isEnglish: Bool { language == "en" }

    static var usesLargeText: Bool {
        ProcessInfo.processInfo.environment["CORBIE_UI_LARGE_TEXT"] == "1"
    }

    static var usesDarkAppearance: Bool {
        ProcessInfo.processInfo.environment["CORBIE_UI_APPEARANCE"] == "dark"
    }

    static var screenshotPrefix: String {
        ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_PREFIX"] ?? ""
    }

    static var screenshotDirectory: String? {
        ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]
    }

    static var locale: String {
        switch language {
        case "de": return "de_DE"
        case "es": return "es_ES"
        case "fr": return "fr_FR"
        case "it": return "it_IT"
        default: return "en_US"
        }
    }
}

enum QAText {
    static let add = "Add"
    static let save = "Save"
    static let cancel = "Cancel"
    static let next = "Continue"
    static let later = "Later"
    static let debugSignIn = "continue without Apple ID (debug build)"
    static let tabs = ["Tasks", "Calendar", "Wishes", "Plans", "Us"]
}

enum QATab {
    static let tasks = 0
    static let calendar = 1
    static let wishes = 2
    static let plans = 3
    static let us = 4
}

extension XCUIApplication {
    static func corbie() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(QARun.language))", "-AppleLocale", QARun.locale]
        if QARun.usesLargeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityL",
            ]
        }
        return app
    }

    func anyElement(labelContaining text: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    var navigationAdd: XCUIElement {
        navigationBars.buttons[QAText.add].firstMatch
    }

    var tabBarButtons: XCUIElementQuery {
        tabBars.firstMatch.buttons
    }
}

extension XCTestCase {
    func applyAppearance() {
        XCUIDevice.shared.appearance = QARun.usesDarkAppearance ? .dark : .light
    }

    @discardableResult
    func launchSignedIn(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        applyAppearance()
        let app = XCUIApplication.corbie()
        app.launch()
        if QARun.isEnglish {
            passOnboardingIfShown(app)
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 30) == false {
            saveScreenshot(app, named: "no_tab_bar")
            XCTFail("the tab bar never appeared", file: file, line: line)
        }
        return app
    }

    func passOnboardingIfShown(_ app: XCUIApplication) {
        let debugSignIn = app.buttons[QAText.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 12) else { return }
        UITestFlows.waitUntilHittable(debugSignIn)
        debugSignIn.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 25), "the profile step never appeared")
        if (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        let next = app.buttons[QAText.next]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "the profile step has no continue button")
        next.tap()

        let later = app.buttons[QAText.later]
        XCTAssertTrue(later.waitForExistence(timeout: 40), "the invite step never appeared")
        later.tap()
    }

    func selectTab(_ app: XCUIApplication, _ index: Int) {
        let button = app.tabBarButtons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 20), "tab \(index) is missing")
        button.tap()
    }

    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 20), "a field to type into is missing", file: file, line: line)
        field.tap()
        field.typeText(text)
    }

    @discardableResult
    func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) -> Bool {
        for _ in 0 ..< maxSwipes {
            if element.exists, element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    func saveScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = QARun.screenshotDirectory else { return }
        let file = QARun.screenshotPrefix.isEmpty ? name : QARun.screenshotPrefix + "_" + name
        let url = URL(fileURLWithPath: directory).appendingPathComponent(file + ".png")
        try? shot.pngRepresentation.write(to: url)
    }

    func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(Int(Date().timeIntervalSince1970) % 100_000)"
    }
}
