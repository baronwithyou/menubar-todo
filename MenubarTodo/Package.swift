// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MenubarTodo",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "MenubarTodo", targets: ["MenubarTodo"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MenubarTodo",
            path: ".",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
