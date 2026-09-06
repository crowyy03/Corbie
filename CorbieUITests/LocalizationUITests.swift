import XCTest

struct LocalizedRun {
    let language: String
    let debugSignIn: String
    let cont: String
    let later: String
    let tabs: [String]
    let planSegments: [String]
    let usPill: String
    let close: String
}

final class LocalizationUITests: XCTestCase {
    private let screenshotDirectory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]

    private static let english = LocalizedRun(
        language: "en",
        debugSignIn: "continue without Apple ID (debug build)",
        cont: "Continue",
        later: "Later",
        tabs: ["Today", "Tasks", "Calendar", "Wishes", "Plans"],
        planSegments: ["Big", "Lists"],
        usPill: "Open the Us hub",
        close: "Close"
    )

    private static let german = LocalizedRun(
        language: "de",
        debugSignIn: "ohne Apple-ID weiter (Debug-Build)",
        cont: "Weiter",
        later: "Sp\u{E4}ter",
        tabs: ["Heute", "Aufgaben", "Kalender", "W\u{FC}nsche", "Pl\u{E4}ne"],
        planSegments: ["Gro\u{DF}", "Listen"],
        usPill: "Wir \u{F6}ffnen",
        close: "Schlie\u{DF}en"
    )

    private static let spanish = LocalizedRun(
        language: "es",
        debugSignIn: "seguir sin Apple ID (compilaci\u{F3}n de prueba)",
        cont: "Continuar",
        later: "Luego",
        tabs: ["Hoy", "Tareas", "Calendario", "Deseos", "Planes"],
        planSegments: ["Grandes", "Listas"],
        usPill: "Abrir Nosotros",
        close: "Cerrar"
    )

    private static let french = LocalizedRun(
        language: "fr",
        debugSignIn: "continuer sans identifiant Apple (build de test)",
        cont: "Continuer",
        later: "Plus tard",
        tabs: ["Aujourd'hui", "T\u{E2}ches", "Calendrier", "Souhaits", "Projets"],
        planSegments: ["Gros", "Listes"],
        usPill: "Ouvrir Nous",
        close: "Fermer"
    )

    private static let italian = LocalizedRun(
        language: "it",
        debugSignIn: "continua senza Apple ID (build di test)",
        cont: "Continua",
        later: "Pi\u{F9} tardi",
        tabs: ["Oggi", "Attivit\u{E0}", "Calendario", "Desideri", "Progetti"],
        planSegments: ["Grandi", "Liste"],
        usPill: "Apri Noi",
        close: "Chiudi"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishFitsTheTabsSegmentsAndPill() throws {
        try run(Self.english)
    }

    func testGermanFitsTheTabsSegmentsAndPill() throws {
        try run(Self.german)
    }

    func testSpanishFitsTheTabsSegmentsAndPill() throws {
        try run(Self.spanish)
    }

    func testFrenchFitsTheTabsSegmentsAndPill() throws {
        try run(Self.french)
    }

    func testItalianFitsTheTabsSegmentsAndPill() throws {
        try run(Self.italian)
    }

    private func run(_ localization: LocalizedRun) throws {
        let app = XCUIApplication.corbie(language: localization.language)
        app.launch()

        passOnboarding(app, localization)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), localization.language)
        XCTAssertEqual(tabBar.buttons.count, localization.tabs.count, localization.language)

        for (index, title) in localization.tabs.enumerated() {
            let button = tabBar.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(localization.language): \(title)")
            button.tap()
            save(app, localization, "tab\(index)")
        }

        try checkPlanSegments(app, localization)
        try checkUsHub(app, localization, tabBar: tabBar)
    }

    private func checkPlanSegments(_ app: XCUIApplication, _ localization: LocalizedRun) throws {
        for title in localization.planSegments {
            let segment = app.buttons[title].firstMatch
            XCTAssertTrue(segment.waitForExistence(timeout: 10), "\(localization.language): \(title)")
        }
        let lists = app.buttons[localization.planSegments[1]].firstMatch
        lists.tap()
        save(app, localization, "plans_lists")
    }

    private func checkUsHub(_ app: XCUIApplication, _ localization: LocalizedRun, tabBar: XCUIElement) throws {
        tabBar.buttons[localization.tabs[0]].tap()
        let pill = app.buttons[localization.usPill].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "\(localization.language): \(localization.usPill)")
        pill.tap()
        let close = app.buttons[localization.close].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15), "\(localization.language): \(localization.close)")
        save(app, localization, "us_hub")
        close.tap()
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), localization.language)
    }

    private func passOnboarding(_ app: XCUIApplication, _ localization: LocalizedRun) {
        let debugSignIn = app.buttons[localization.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 15) else { return }
        save(app, localization, "onboarding_intro")
        debugSignIn.tap()

        let continueButton = app.buttons[localization.cont]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 20), localization.language)
        save(app, localization, "onboarding_profile")
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons[localization.later]
        XCTAssertTrue(later.waitForExistence(timeout: 25), localization.language)
        save(app, localization, "onboarding_invite")
        later.tap()
    }

    private func save(_ app: XCUIApplication, _ localization: LocalizedRun, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name + "_" + localization.language
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let screenshotDirectory else { return }
        let folder = URL(fileURLWithPath: screenshotDirectory).appendingPathComponent(localization.language)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
