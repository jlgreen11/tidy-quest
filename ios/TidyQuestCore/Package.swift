// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TidyQuestCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15)   // required by supabase-swift transitive deps; iOS 17 is the deployment target
    ],
    products: [
        .library(
            name: "TidyQuestCore",
            targets: ["TidyQuestCore"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/supabase/supabase-swift",
            from: "2.0.0"
        ),
        // swift-testing is bundled with Swift 6+ toolchain.
        // The explicit package dependency below is kept for compatibility with
        // older Xcode 15 CI images. Remove when CI uses Xcode 16+.
        .package(
            url: "https://github.com/apple/swift-testing.git",
            from: "0.10.0"
        )
    ],
    targets: [
        .target(
            name: "TidyQuestCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/TidyQuestCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "TidyQuestCoreTests",
            dependencies: [
                "TidyQuestCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TidyQuestCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
