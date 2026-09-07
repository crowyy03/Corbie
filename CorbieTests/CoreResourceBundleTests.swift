import CorbieCore
import XCTest

final class CoreResourceBundleTests: XCTestCase {
    func testTheChoreCatalogLoadsFromInsideTheAppBundle() {
        XCTAssertEqual(ChoreCatalog.bundled.items.count, 44)
        XCTAssertFalse(ChoreCatalog.bundled.preselectedIds.isEmpty)
    }

    func testEveryChoreGroupHasAName() {
        for group in ChoreGroup.allCases {
            let name = String(localized: String.LocalizationValue(group.titleKey))
            XCTAssertNotEqual(name, group.titleKey, group.rawValue)
            XCTAssertFalse(ChoreCatalog.bundled.items(in: group).isEmpty, group.rawValue)
        }
    }

    func testTheQuestionsDirectoryIsReachableFromInsideTheAppBundle() throws {
        let directory = try XCTUnwrap(QuestionBank.bundledDirectory)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(QuestionBank.bundled.entries.count, QuestionBank.bundled.questionIds.count)
    }
}
