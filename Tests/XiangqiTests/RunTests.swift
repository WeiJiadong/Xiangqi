import Foundation

@main
struct RunTests {
    static func main() async {
        setbuf(stdout, nil)  // 崩溃时不丢已打印结果
        var failures = 0
        let suites = FenTests.all + RulesTests.all + NotationTests.all + UCIParserTests.all
        for (name, test) in suites {
            let fs = test().compactMap { $0 }
            report(name, fs, &failures)
        }
        // 引擎集成测试放最后（慢，真跑皮卡鱼）
        for (name, test) in EngineIntegrationTests.all {
            let fs = await test().compactMap { $0 }
            report(name, fs, &failures)
        }

        if failures == 0 {
            print("\nALL PASS")
        } else {
            print("\n\(failures) FAILURE(S)")
            exit(1)
        }
    }

    private static func report(_ name: String, _ fs: [String], _ failures: inout Int) {
        if fs.isEmpty {
            print("PASS \(name)")
        } else {
            failures += fs.count
            for f in fs { print("FAIL \(name): \(f)") }
        }
    }
}
