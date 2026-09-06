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

    static var appearance: String {
        let value = ProcessInfo.processInfo.environment["CORBIE_UI_APPEARANCE"] ?? "system"
        return ["system", "light", "dark"].contains(value) ? value : "system"
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

private final class QACatalogAnchor {}

enum QACatalog {
    private static let table = "Localizable"
    private static let missing = "\u{0}corbie.missing"

    static let languages: [String] = {
        let host = Bundle(for: QACatalogAnchor.self)
        return host.localizations.filter { $0 != "Base" }.sorted()
    }()

    private static let bundles: [String: Bundle] = {
        let host = Bundle(for: QACatalogAnchor.self)
        return languages.reduce(into: [:]) { result, language in
            guard let path = host.path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return }
            result[language] = bundle
        }
    }()

    static func has(_ key: String, language: String) -> Bool {
        guard let bundle = bundles[language] else { return false }
        let value = bundle.localizedString(forKey: key, value: missing, table: table)
        return value != missing && value.isEmpty == false
    }

    static func text(_ key: String, language: String = QARun.language) -> String {
        for candidate in [language, "en"] {
            guard let bundle = bundles[candidate] else { continue }
            let value = bundle.localizedString(forKey: key, value: missing, table: table)
            if value != missing, value.isEmpty == false { return value }
        }
        return key
    }

    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), arguments: arguments)
    }
}

enum QATab: Int, CaseIterable {
    case today
    case tasks
    case calendar
    case wishes
    case plans

    var titleKey: String {
        switch self {
        case .today: return "tab.today.title"
        case .tasks: return "tab.tasks.title"
        case .calendar: return "tab.calendar.title"
        case .wishes: return "tab.wishes.title"
        case .plans: return "tab.plans.title"
        }
    }

    var title: String { QACatalog.text(titleKey) }

    var screenshotName: String { "tab\(rawValue)_" + String(describing: self) }
}

enum QAText {
    static var add: String { QACatalog.text("common.action.add") }
    static var save: String { QACatalog.text("common.action.save") }
    static var cancel: String { QACatalog.text("common.action.cancel") }
    static var close: String { QACatalog.text("common.action.close") }
    static var done: String { QACatalog.text("common.action.done") }
    static var later: String { QACatalog.text("pairing.invite.later") }
    static var cont: String { QACatalog.text("onboarding.profile.continue") }
    static var debugSignIn: String { QACatalog.text("onboarding.debug.signin") }
    static var usPill: String { QACatalog.text("us.pill.label") }
    static var usPillWithDot: String { QACatalog.text("us.pill.label.new") }
    static var sharedSettings: String { QACatalog.text("us.hub.settings") }
    static var settingsTitle: String { QACatalog.text("settings.title") }
    static var paywallHeadline: String { QACatalog.text("paywall.headline") }
    static let developer = "Developer"
    static let expireTrial = "Expire the trial"
}

extension XCUIApplication {
    static let themePreferenceDefaultsKey = "corbie.design.themePreference"

    static func corbie(
        startsEmpty: Bool = true,
        appearance: String = QARun.appearance,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(QARun.language))", "-AppleLocale", QARun.locale]
        app.launchArguments += ["-" + themePreferenceDefaultsKey, appearance]
        app.launchArguments += extraArguments
        if startsEmpty {
            app.launchArguments += ["-corbie-erase-everything"]
        }
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

    func button(labelContaining text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    var navigationAdd: XCUIElement {
        navigationBars.buttons[QAText.add].firstMatch
    }

    var usPill: XCUIElement {
        buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR label == %@", QAText.usPill, QAText.usPillWithDot)
        ).firstMatch
    }

    var tabBarButtons: XCUIElementQuery {
        tabBars.firstMatch.buttons
    }
}

extension XCTestCase {
    @discardableResult
    func launchSignedIn(
        startsEmpty: Bool = true,
        appearance: String = QARun.appearance,
        extraArguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication.corbie(
            startsEmpty: startsEmpty,
            appearance: appearance,
            extraArguments: extraArguments
        )
        app.launch()
        passOnboardingIfShown(app, file: file, line: line)
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 60) == false {
            saveScreenshot(app, named: "no_tab_bar")
            XCTFail("the tab bar never appeared", file: file, line: line)
        }
        return app
    }

    func passOnboardingIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let debugSignIn = app.buttons[QAText.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 30) else { return }
        UITestFlows.waitUntilHittable(debugSignIn)
        debugSignIn.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 40), "the profile step never appeared", file: file, line: line)
        if (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        let next = app.buttons[QAText.cont]
        XCTAssertTrue(next.waitForExistence(timeout: 20), "the profile step has no continue", file: file, line: line)
        next.tap()

        let later = app.buttons[QAText.later]
        XCTAssertTrue(later.waitForExistence(timeout: 60), "the invite step never appeared", file: file, line: line)
        later.tap()
    }

    func selectTab(_ app: XCUIApplication, _ tab: QATab, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.tabBarButtons.element(boundBy: tab.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: 30), "the \(tab) tab is missing", file: file, line: line)
        button.tap()
    }

    func openUsHub(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let pill = app.usPill
        XCTAssertTrue(pill.waitForExistence(timeout: 30), "the toolbar has no Us pill", file: file, line: line)
        UITestFlows.waitUntilHittable(pill)
        pill.tap()
        XCTAssertTrue(
            app.buttons[QAText.close].firstMatch.waitForExistence(timeout: 30),
            "the Us hub did not open",
            file: file,
            line: line
        )
    }

    func closeUsHub(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let close = app.buttons[QAText.close].firstMatch
        for _ in 0 ..< 4 where close.exists == false {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = close.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(close.waitForExistence(timeout: 20), "the Us hub has no way out", file: file, line: line)
        close.tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "closing the Us hub stranded the app",
            file: file,
            line: line
        )
    }

    func openUsTile(_ app: XCUIApplication, key: String, file: StaticString = #filePath, line: UInt = #line) {
        let tile = app.button(labelContaining: QACatalog.text(key))
        XCTAssertTrue(
            tile.waitForExistence(timeout: 30),
            "the Us hub has no tile for \(key)",
            file: file,
            line: line
        )
        tile.tap()
    }

    func settingsRow(_ app: XCUIApplication, _ key: String) -> XCUIElement {
        app.collectionViews.buttons[QACatalog.text(key)].firstMatch
    }

    func settingsSwitch(_ app: XCUIApplication, _ key: String) -> XCUIElement {
        app.collectionViews.switches[QACatalog.text(key)].firstMatch
    }

    func openSharedSettings(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openUsHub(app, file: file, line: line)
        let settings = app.button(labelContaining: QAText.sharedSettings)
        XCTAssertTrue(
            scrollTo(settings, in: app),
            "the Us hub has no row called \(QAText.sharedSettings)",
            file: file,
            line: line
        )
        settings.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.settingsTitle].waitForExistence(timeout: 30),
            "settings did not open",
            file: file,
            line: line
        )
    }

    func openDeveloperMenu(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openSharedSettings(app, file: file, line: line)
        let developer = app.collectionViews.buttons[QAText.developer].firstMatch
        XCTAssertTrue(scrollTo(developer, in: app), "settings has no developer menu", file: file, line: line)
        developer.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.developer].waitForExistence(timeout: 30),
            "the developer menu did not open",
            file: file,
            line: line
        )
    }

    @discardableResult
    func denySystemPromptIfShown(timeout: TimeInterval = 8) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = ["Don't Allow", "Don\u{2019}t Allow", "Nicht erlauben"]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in labels {
                let deny = springboard.buttons[label]
                if deny.exists, deny.isHittable {
                    deny.tap()
                    return true
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        } while Date() < deadline
        return false
    }

    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 30), "a field to type into is missing", file: file, line: line)
        UITestFlows.waitUntilHittable(field)
        field.tap()
        field.typeText(text)
    }

    @discardableResult
    func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 12) -> Bool {
        for _ in 0 ..< maxSwipes {
            if element.exists, element.isHittable { break }
            app.swipeUp()
        }
        guard element.exists, element.isHittable else { return false }
        waitUntilStill(element)
        return true
    }

    func waitUntilStill(_ element: XCUIElement, timeout: TimeInterval = 4) {
        var previous = element.frame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            let current = element.frame
            if current == previous { return }
            previous = current
        }
    }

    func hittableElement(_ query: XCUIElementQuery, timeout: TimeInterval = 25) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for index in 0 ..< query.count {
                let element = query.element(boundBy: index)
                if element.exists, element.isHittable { return element }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return nil
    }

    func saveScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = QARun.screenshotDirectory else { return }
        let file = QARun.screenshotPrefix.isEmpty ? name : QARun.screenshotPrefix + "_" + name
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: directory),
            withIntermediateDirectories: true
        )
        let url = URL(fileURLWithPath: directory).appendingPathComponent(file + ".png")
        try? shot.pngRepresentation.write(to: url)
    }

    func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(Int(Date().timeIntervalSince1970 * 1000) % 1_000_000)"
    }

    func monthAndDay(daysFromNow: Int) -> (month: Int, day: Int, monthName: String) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        let parts = calendar.dateComponents([.month, .day], from: date)
        let month = parts.month ?? 1
        return (month, parts.day ?? 1, DateFormatter().monthSymbols[month - 1])
    }
}
