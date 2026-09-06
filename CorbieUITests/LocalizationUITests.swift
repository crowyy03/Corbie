import XCTest

struct LocalizedRun {
    let language: String
    let locale: String
    let debugSignIn: String
    let cont: String
    let later: String
    let tabs: [String]
    let usPill: String
    let newFolder: String
    let freeTime: String
    let notNow: String
}

final class LocalizationUITests: XCTestCase {
    private let screenshotDirectory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]

    private static let english = LocalizedRun(
        language: "en",
        locale: "en_US",
        debugSignIn: "continue without Apple ID (debug build)",
        cont: "Continue",
        later: "Later",
        tabs: ["Today", "Tasks", "Calendar", "Wishes", "Goals"],
        usPill: "Open the Us hub",
        newFolder: "New folder",
        freeTime: "When you two are free",
        notNow: "Not now"
    )

    private static let german = LocalizedRun(
        language: "de",
        locale: "de_DE",
        debugSignIn: "ohne Apple-ID weiter (Debug-Build)",
        cont: "Weiter",
        later: "Später",
        tabs: ["Heute", "Aufgaben", "Kalender", "Wünsche", "Ziele"],
        usPill: "Wir öffnen",
        newFolder: "Neuer Ordner",
        freeTime: "Wann ihr beide frei seid",
        notNow: "Jetzt nicht"
    )

    private static let spanish = LocalizedRun(
        language: "es",
        locale: "es_ES",
        debugSignIn: "seguir sin Apple ID (compilación de prueba)",
        cont: "Continuar",
        later: "Luego",
        tabs: ["Hoy", "Tareas", "Calendario", "Deseos", "Objetivos"],
        usPill: "Abrir Nosotros",
        newFolder: "Nueva carpeta",
        freeTime: "Cuando estáis libres los dos",
        notNow: "Ahora no"
    )

    private static let french = LocalizedRun(
        language: "fr",
        locale: "fr_FR",
        debugSignIn: "continuer sans identifiant Apple (build de test)",
        cont: "Continuer",
        later: "Plus tard",
        tabs: ["Aujourd'hui", "Tâches", "Calendrier", "Souhaits", "Objectifs"],
        usPill: "Ouvrir Nous",
        newFolder: "Nouveau dossier",
        freeTime: "Quand vous êtes libres tous les deux",
        notNow: "Pas maintenant"
    )

    private static let italian = LocalizedRun(
        language: "it",
        locale: "it_IT",
        debugSignIn: "continua senza Apple ID (build di test)",
        cont: "Continua",
        later: "Più tardi",
        tabs: ["Oggi", "Attività", "Calendario", "Desideri", "Obiettivi"],
        usPill: "Apri Noi",
        newFolder: "Nuova cartella",
        freeTime: "Quando siete liberi tutti e due",
        notNow: "Non ora"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishRendersEveryTabAndChip() throws {
        try run(Self.english)
    }

    func testGermanRendersEveryTabAndChip() throws {
        try run(Self.german)
    }

    func testSpanishRendersEveryTabAndChip() throws {
        try run(Self.spanish)
    }

    func testFrenchRendersEveryTabAndChip() throws {
        try run(Self.french)
    }

    func testItalianRendersEveryTabAndChip() throws {
        try run(Self.italian)
    }

    private func run(_ localization: LocalizedRun) throws {
        let app = launch(localization)
        passOnboarding(app, localization)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), localization.language)
        XCTAssertEqual(tabBar.buttons.count, localization.tabs.count)
        for button in tabBar.buttons.allElementsBoundByIndex {
            XCTAssertFalse(button.label.isEmpty, "\(localization.language): a tab has no text")
        }

        for (index, title) in localization.tabs.enumerated() {
            let button = tabBar.buttons[title]
            XCTAssertTrue(button.waitForExistence(timeout: 8), "\(localization.language): \(title)")
            button.tap()
            save(app, localization, "tab\(index)_\(title.lowercased())")
        }

        try folderEditor(app, localization)
        try freeTime(app, localization)
        try usHub(app, localization)
    }

    private func folderEditor(_ app: XCUIApplication, _ localization: LocalizedRun) throws {
        app.tabBars.buttons[localization.tabs[1]].tap()
        let newFolder = app.buttons[localization.newFolder].firstMatch
        XCTAssertTrue(newFolder.waitForExistence(timeout: 10), "\(localization.language): the new folder button")
        newFolder.tap()
        XCTAssertTrue(
            app.navigationBars[localization.newFolder].waitForExistence(timeout: 10),
            "\(localization.language): the folder editor"
        )
        save(app, localization, "folder_editor")
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func freeTime(_ app: XCUIApplication, _ localization: LocalizedRun) throws {
        app.tabBars.buttons[localization.tabs[2]].tap()
        let entry = app.buttons[localization.freeTime].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "\(localization.language): the free time button")
        entry.tap()

        let notNow = app.buttons[localization.notNow]
        if notNow.waitForExistence(timeout: 8) {
            save(app, localization, "freetime_privacy")
            notNow.tap()
        }
        XCTAssertTrue(
            app.navigationBars[localization.freeTime].waitForExistence(timeout: 10),
            "\(localization.language): the free time screen"
        )
        save(app, localization, "freetime")
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func usHub(_ app: XCUIApplication, _ localization: LocalizedRun) throws {
        let pill = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", localization.usPill)
        ).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 10), "\(localization.language): the Us pill")
        pill.tap()
        save(app, localization, "us_hub")
    }

    private func launch(_ localization: LocalizedRun) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(localization.language))",
            "-AppleLocale", localization.locale,
            "-corbie.freetime.privacynotice.seen", "NO"
        ]
        app.launch()
        return app
    }

    private func passOnboarding(_ app: XCUIApplication, _ localization: LocalizedRun) {
        let debugSignIn = app.buttons[localization.debugSignIn]
        guard debugSignIn.waitForExistence(timeout: 20) else { return }
        save(app, localization, "onboarding_intro")
        debugSignIn.tap()

        let continueButton = app.buttons[localization.cont]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 25), localization.language)
        save(app, localization, "onboarding_profile")
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons[localization.later]
        XCTAssertTrue(later.waitForExistence(timeout: 30), localization.language)
        save(app, localization, "onboarding_invite")
        later.tap()
    }

    private func save(_ app: XCUIApplication, _ localization: LocalizedRun, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(name)_\(localization.language)"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let screenshotDirectory else { return }
        let folder = URL(fileURLWithPath: screenshotDirectory).appendingPathComponent(localization.language)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
