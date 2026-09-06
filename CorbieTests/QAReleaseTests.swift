import XCTest
@testable import Corbie

final class QAReleaseTests: XCTestCase {
    private var info: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    private func englishCatalog() throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: "en"
            ),
            "the app ships no English strings table"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String], "the English strings table is not a dictionary")
    }

    func testExportComplianceIsDeclared() {
        XCTAssertEqual(
            info["ITSAppUsesNonExemptEncryption"] as? Bool,
            false,
            "the app has to answer the export compliance question in its Info.plist"
        )
    }

    func testTheDeepLinkSchemeIsRegistered() throws {
        let types = try XCTUnwrap(info["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemes.contains("corbie"), "corbie:// links cannot reach the app")
    }

    func testSharingAndRemoteChangesAreDeclared() throws {
        XCTAssertEqual(info["CKSharingSupported"] as? Bool, true, "accepting a CKShare needs CKSharingSupported")
        let modes = try XCTUnwrap(info["UIBackgroundModes"] as? [String])
        XCTAssertTrue(modes.contains("remote-notification"), "CloudKit pushes need the background mode")
    }

    func testEveryPermissionTheAppAsksForHasAReason() throws {
        for key in [
            "NSCalendarsFullAccessUsageDescription",
            "NSCalendarsWriteOnlyAccessUsageDescription",
            "NSPhotoLibraryUsageDescription",
        ] {
            let value = try XCTUnwrap(info[key] as? String, "\(key) is missing")
            XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(key) is empty")
        }
    }

    func testNoReasonIsDeclaredForAPermissionTheAppNeverAsksFor() {
        for key in [
            "NSLocationWhenInUseUsageDescription",
            "NSLocationAlwaysAndWhenInUseUsageDescription",
            "NSCameraUsageDescription",
            "NSContactsUsageDescription",
            "NSFaceIDUsageDescription",
            "NSMicrophoneUsageDescription",
        ] {
            XCTAssertNil(info[key], "\(key) promises a permission the app never asks for")
        }
    }

    func testTheAppShipsTheFiveLanguagesTheSpecNames() {
        let localizations = Set(Bundle.main.localizations).subtracting(["Base"])
        XCTAssertEqual(localizations, ["en", "de", "es", "fr", "it"])
    }

    func testNoPlaceholderCopyReachesTheEnglishStrings() throws {
        let catalog = try englishCatalog()
        XCTAssertGreaterThan(catalog.count, 500, "the English strings table looks truncated")
        for (key, value) in catalog {
            let lowered = value.lowercased()
            for marker in ["lorem", "todo", "fixme", "placeholder", "tbd", "xxx"] {
                XCTAssertFalse(lowered.contains(marker), "\(key) still reads like a placeholder: \(value)")
            }
        }
    }

    func testTheEnglishCopyKeepsTheBrandRules() throws {
        for (key, value) in try englishCatalog() {
            XCTAssertFalse(value.contains("!"), "\(key) has an exclamation mark")
            XCTAssertFalse(value.contains("\u{2014}"), "\(key) has an em dash")
            XCTAssertFalse(value.contains("\u{2192}"), "\(key) has an arrow")
        }
    }
}
