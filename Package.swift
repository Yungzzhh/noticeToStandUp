// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "StandUpReminder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StandUpReminder", targets: ["StandUpReminder"])
    ],
    targets: [
        .target(name: "ReminderCore"),
        .executableTarget(
            name: "StandUpReminder",
            dependencies: ["ReminderCore"]
        ),
        .testTarget(
            name: "ReminderCoreTests",
            dependencies: ["ReminderCore", "StandUpReminder"]
        )
    ]
)
