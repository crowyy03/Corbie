import CorbieCore
import XCTest
@testable import Corbie

final class StoreConfigurationTests: XCTestCase {
    private struct StoreKitConfiguration: Decodable {
        struct Group: Decodable {
            let subscriptions: [Subscription]
        }

        struct Subscription: Decodable {
            let productID: String
        }

        let subscriptionGroups: [Group]
    }

    func testTheAppBundleNamesBothProducts() {
        let identifiers = StoreProductIdentifiers(bundle: .main)
        XCTAssertEqual(identifiers.all.count, CorbieProduct.allCases.count)
        for product in CorbieProduct.allCases {
            XCTAssertNotNil(identifiers.identifier(for: product), "no product id for \(product) in the Info.plist")
        }
        XCTAssertEqual(StoreService.shared.productIdentifiers, identifiers)
    }

    func testTheBundleProductsAreTheOnesInTheLocalStoreKitFile() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repository.appendingPathComponent("Products.storekit"))
        let configuration = try JSONDecoder().decode(StoreKitConfiguration.self, from: data)
        let local = Set(configuration.subscriptionGroups.flatMap(\.subscriptions).map(\.productID))
        XCTAssertEqual(Set(StoreProductIdentifiers(bundle: .main).all), local)
    }
}
