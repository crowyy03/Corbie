// swift-tools-version:5.10
import Foundation
import PackageDescription

let usesExternalSwiftTesting = ProcessInfo.processInfo.environment["CORBIE_EXTERNAL_TESTING"] == "1"

var dependencies: [Package.Dependency] = []
var testDependencies: [Target.Dependency] = ["CorbieCore"]
if usesExternalSwiftTesting {
    dependencies.append(.package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.1.3"))
    testDependencies.append(.product(name: "Testing", package: "swift-testing"))
}

let package = Package(
    name: "CorbieCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CorbieCore", targets: ["CorbieCore"])
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "CorbieCore",
            path: "Sources/CorbieCore",
            resources: [.process("Resources")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "CorbieCoreTests",
            dependencies: testDependencies,
            path: "Tests/CorbieCoreTests"
        )
    ]
)
