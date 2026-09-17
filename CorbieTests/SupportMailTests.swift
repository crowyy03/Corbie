import XCTest
@testable import Corbie

final class SupportMailTests: XCTestCase {
    private let mail = SupportMail(
        address: "support@yourcorbie.app",
        subject: "Corbie support",
        deviceModel: "iPhone17,3",
        systemVersion: "iOS 26.5",
        appVersion: "1.0",
        appBuild: "7"
    )

    func testTheSupportAddressAndSubjectComeFromTheCatalog() {
        let current = SupportMail.current()
        XCTAssertEqual(current.address, "support@yourcorbie.app")
        XCTAssertEqual(current.subject, "Corbie support")
        XCTAssertFalse(current.deviceModel.isEmpty)
        XCTAssertFalse(current.appVersion.isEmpty)
        XCTAssertFalse(current.appBuild.isEmpty)
    }

    func testTheLinkOpensAMailToSupportWithTheSubject() throws {
        let url = try XCTUnwrap(mail.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.path, "support@yourcorbie.app")
        XCTAssertEqual(components.queryItems?.first { $0.name == "subject" }?.value, "Corbie support")
    }

    func testTheBodyCarriesTheEnvironmentAndNothingElse() throws {
        let url = try XCTUnwrap(mail.url)
        let body = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "body" }?.value
        )
        XCTAssertTrue(body.contains("iPhone17,3"))
        XCTAssertTrue(body.contains("iOS 26.5"))
        XCTAssertTrue(body.contains("1.0 (7)"))
        let uuid = try NSRegularExpression(pattern: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-")
        XCTAssertNil(uuid.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)))
        XCTAssertFalse(body.contains("@"))
    }

    func testTheOnlyAddressInTheCatalogIsSupport() throws {
        let catalog = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en"))
        let values = try XCTUnwrap(NSDictionary(contentsOfFile: catalog) as? [String: String]).values
        let email = try NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        let addresses = values.flatMap { value in
            email.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { match in
                Range(match.range, in: value).map { String(value[$0]) }
            }
        }
        XCTAssertEqual(Set(addresses), ["support@yourcorbie.app"])
    }
}
