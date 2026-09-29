// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Xiangqi",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "XiangqiCore", path: "Sources/XiangqiCore"),
        .executableTarget(
            name: "Xiangqi",
            dependencies: ["XiangqiCore"],
            path: "Sources/Xiangqi"
        ),
        // CLT 工具链无 XCTest/Swift Testing，测试用独立可执行目标跑。
        .executableTarget(
            name: "XiangqiTests",
            dependencies: ["XiangqiCore"],
            path: "Tests/XiangqiTests"
        ),
    ]
)
