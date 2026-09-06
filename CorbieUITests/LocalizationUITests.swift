import XCTest

struct LocalizedRun {
    let language: String
    let locale: String
    let debugSignIn: String
    let cont: String
    let later: String
    let tabs: [String]
}

final class LocalizationUITests: XCTestCase {
    private let screenshotDirectory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]

    private static let english = LocalizedRun(
        language: "en",
        locale: "en_US",
        debugSignIn: "continue without Apple ID (debug build)",
        cont: "Continue",
        later: "Later",
        tabs: ["Tasks", "Calendar", "Wishes", "Plans", "Us"]
    )

    private static let german = LocalizedRun(
        language: "de",
        locale: "de_DE",
        debugSignIn: "ohne Apple-ID weiter (Debug-Build)",
        cont: "Weiter",
        later: "Später",
        tabs: ["Aufgaben", "Kalender", "Wünsche", "Pläne", "Wir"]
    )

    private static let spanish = LocalizedRun(
        language: "es",
        locale: "es_ES",
        debugSignIn: "seguir sin Apple ID (compilación de prueba)",
        cont: "Continuar",
        later: "Luego",
        tabs: ["Tareas", "Calendario", "Deseos", "Planes", "Nosotros"]
    )

    private static let french = LocalizedRun(
        language: "fr",
        locale: "fr_FR",
        debugSignIn: "continuer sans identifiant Apple (build de test)",
        cont: "Continuer",
        later: "Plus tard",
        tabs: ["Tâches", "Calendrier", "Souhaits", "Projets", "Nous"]
    )

    private static let italian = LocalizedRun(
        language: "it",
        locale: "it_IT",
        debugSignIn: "continua senza Apple ID (build di test)",
        cont: "Continua",
        later: "Più tardi",
        tabs: ["Attività", "Calendario", "Desideri", "Progetti", "Noi"]
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishTabsFitTheTabBar() throws {
        try run(Self.english)
    }

    func testGermanTabsFitTheTabBar() throws {
        try run(Self.german)
    }

    func testSpanishTabsFitTheTabBar() throws {
        try run(Self.spanish)
    }

    func testFrenchTabsFitTheTabBar() throws {
        try run(Self.french)
    }

    func testItalianTabsFitTheTabBar() throws {
        try run(Self.italian)
    }

    private func run(_ localization: LocalizedRun) throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(localization.language))",
            "-AppleLocale", localization.locale
        ]
        app.launch()

        passOnboarding(app, localization)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), localization.language)
        XCTAssertEqual(tabBar.buttons.count, localization.tabs.count)

        for (index, title) in localization.tabs.enumerated() {
            let button = tabBar.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(localization.language): \(title)")
            button.tap()
            save(app, localization, "tab\(index)_\(localization.language)")
        }
    }

    private func passOnboarding(_ app: XCUIApplication, _ localization: LocalizedRun) {
        let debugSignIn = app.buttons[localization.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 15) else { return }
        save(app, localization, "onboarding_intro_\(localization.language)")
        debugSignIn.tap()

        let continueButton = app.buttons[localization.cont]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 20), localization.language)
        save(app, localization, "onboarding_profile_\(localization.language)")
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons[localization.later]
        XCTAssertTrue(later.waitForExistence(timeout: 25), localization.language)
        save(app, localization, "onboarding_invite_\(localization.language)")
        later.tap()
    }

    private func save(_ app: XCUIApplication, _ localization: LocalizedRun, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let screenshotDirectory else { return }
        let folder = URL(fileURLWithPath: screenshotDirectory).appendingPathComponent(localization.language)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
