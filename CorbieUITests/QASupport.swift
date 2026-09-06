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
    static let close = "Close"
    static let done = "Done"
    static let later = "Later"
    static let debugSignIn = "continue without Apple ID (debug build)"
    static let usPill = "Open the Us hub"
    static let usPillWithDot = "Open the Us hub, something new"
    static let sharedSettings = "Shared settings"
    static let settingsTitle = "Settings"
    static let developer = "Developer"
    static let paywallHeadline = "One subscription. Both of you."
    static let tabs = ["Today", "Tasks", "Calendar", "Wishes", "Goals"]
}

enum QATab {
    static let today = 0
    static let tasks = 1
    static let calendar = 2
    static let wishes = 3
    static let goals = 4
}

struct QALabels {
    let usPill: String
    let debugSignIn: String
    let cont: String
    let later: String
    let sharedSettings: String
    let settingsTitle: String
    let seePlans: String
    let paywallHeadline: String
    let restore: String
    let privacy: String
    let terms: String

    static let english = QALabels(
        usPill: "Open the Us hub",
        debugSignIn: "continue without Apple ID (debug build)",
        cont: "Continue",
        later: "Later",
        sharedSettings: "Shared settings",
        settingsTitle: "Settings",
        seePlans: "See plans",
        paywallHeadline: "One subscription. Both of you.",
        restore: "Restore purchases",
        privacy: "Privacy Policy",
        terms: "Terms of Use"
    )

    static let byLanguage: [String: QALabels] = [
        "en": english,
        "de": QALabels(
            usPill: "Wir öffnen",
            debugSignIn: "ohne Apple-ID weiter (Debug-Build)",
            cont: "Weiter",
            later: "Später",
            sharedSettings: "Gemeinsame Einstellungen",
            settingsTitle: "Einstellungen",
            seePlans: "Abos ansehen",
            paywallHeadline: "Ein Abo. Für euch beide.",
            restore: "Käufe wiederherstellen",
            privacy: "Datenschutz",
            terms: "Nutzungsbedingungen"
        ),
        "es": QALabels(
            usPill: "Abrir Nosotros",
            debugSignIn: "seguir sin Apple ID (compilación de prueba)",
            cont: "Continuar",
            later: "Luego",
            sharedSettings: "Ajustes compartidos",
            settingsTitle: "Ajustes",
            seePlans: "Ver planes",
            paywallHeadline: "Una suscripción. Para los dos.",
            restore: "Restaurar compras",
            privacy: "Privacidad",
            terms: "Términos de uso"
        ),
        "fr": QALabels(
            usPill: "Ouvrir Nous",
            debugSignIn: "continuer sans identifiant Apple (build de test)",
            cont: "Continuer",
            later: "Plus tard",
            sharedSettings: "Réglages partagés",
            settingsTitle: "Réglages",
            seePlans: "Voir les offres",
            paywallHeadline: "Un abonnement. Pour vous deux.",
            restore: "Restaurer les achats",
            privacy: "Confidentialité",
            terms: "Conditions d'utilisation"
        ),
        "it": QALabels(
            usPill: "Apri Noi",
            debugSignIn: "continua senza Apple ID (build di test)",
            cont: "Continua",
            later: "Più tardi",
            sharedSettings: "Impostazioni condivise",
            settingsTitle: "Impostazioni",
            seePlans: "Vedi i piani",
            paywallHeadline: "Un abbonamento. Per tutti e due.",
            restore: "Ripristina gli acquisti",
            privacy: "Privacy",
            terms: "Termini d'uso"
        ),
    ]

    static var current: QALabels {
        byLanguage[QARun.language] ?? english
    }
}

extension XCUIApplication {
    static func corbie(startsEmpty: Bool = true, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(QARun.language))", "-AppleLocale", QARun.locale]
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
            NSPredicate(
                format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                QALabels.current.usPill,
                QAText.usPill
            )
        ).firstMatch
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
    func launchSignedIn(
        startsEmpty: Bool = true,
        extraArguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        applyAppearance()
        let app = XCUIApplication.corbie(startsEmpty: startsEmpty, extraArguments: extraArguments)
        app.launch()
        passOnboardingIfShown(app)
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 60) == false {
            saveScreenshot(app, named: "no_tab_bar")
            XCTFail("the tab bar never appeared", file: file, line: line)
        }
        return app
    }

    func passOnboardingIfShown(_ app: XCUIApplication) {
        let labels = QALabels.current
        let debugSignIn = app.buttons[labels.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 20) else { return }
        UITestFlows.waitUntilHittable(debugSignIn)
        debugSignIn.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "the profile step never appeared")
        if (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        let next = app.buttons[labels.cont]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "the profile step has no continue button")
        next.tap()

        let later = app.buttons[labels.later]
        XCTAssertTrue(later.waitForExistence(timeout: 60), "the invite step never appeared")
        later.tap()
    }

    func selectTab(_ app: XCUIApplication, _ index: Int) {
        let button = app.tabBarButtons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 20), "tab \(index) is missing")
        button.tap()
    }

    func openUsHub(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let pill = app.usPill
        XCTAssertTrue(pill.waitForExistence(timeout: 25), "the toolbar has no Us pill", file: file, line: line)
        pill.tap()
        XCTAssertTrue(
            app.buttons[QAText.close].firstMatch.waitForExistence(timeout: 25),
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
            app.tabBars.firstMatch.waitForExistence(timeout: 25),
            "closing the Us hub stranded the app",
            file: file,
            line: line
        )
    }

    func openSharedSettings(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let labels = QALabels.current
        openUsHub(app, file: file, line: line)
        let settings = app.button(labelContaining: labels.sharedSettings)
        XCTAssertTrue(
            settings.waitForExistence(timeout: 25),
            "the Us hub has no row called \(labels.sharedSettings)",
            file: file,
            line: line
        )
        scrollTo(settings, in: app)
        settings.tap()
        XCTAssertTrue(
            app.navigationBars[labels.settingsTitle].waitForExistence(timeout: 25),
            "settings did not open",
            file: file,
            line: line
        )
    }

    func openDeveloperMenu(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openSharedSettings(app, file: file, line: line)
        let developer = app.buttons[QAText.developer]
        XCTAssertTrue(scrollTo(developer, in: app), "settings has no developer menu", file: file, line: line)
        developer.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.developer].waitForExistence(timeout: 20),
            "the developer menu did not open",
            file: file,
            line: line
        )
    }

    @discardableResult
    func denySystemPromptIfShown(timeout: TimeInterval = 8) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don't Allow"]
        guard deny.waitForExistence(timeout: timeout) else { return false }
        deny.tap()
        return true
    }

    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 25), "a field to type into is missing", file: file, line: line)
        UITestFlows.waitUntilHittable(field)
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
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: directory),
            withIntermediateDirectories: true
        )
        let url = URL(fileURLWithPath: directory).appendingPathComponent(file + ".png")
        try? shot.pngRepresentation.write(to: url)
    }

    func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(Int(Date().timeIntervalSince1970) % 100_000)"
    }

    func birthdayInAFewDays(_ days: Int = 3) -> (month: Int, day: Int, monthName: String) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let parts = calendar.dateComponents([.month, .day], from: date)
        let month = parts.month ?? 1
        return (month, parts.day ?? 1, DateFormatter().monthSymbols[month - 1])
    }
}
