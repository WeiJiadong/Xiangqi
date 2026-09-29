import Foundation
import XiangqiCore

/// 真跑皮卡鱼的集成测试；引擎不存在则整体 SKIP。
enum EngineIntegrationTests {
    private static let enginePath = (NSHomeDirectory() as NSString)
        .appendingPathComponent("pikafish/pikafish")
    private static var available: Bool { FileManager.default.isExecutableFile(atPath: enginePath) }

    static func handshake() async -> [String?] {
        guard available else { print("SKIP EngineIntegrationTests.handshake (no engine)"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [
                (name: "Threads", value: "1"),
                (name: "Hash", value: "16"),
            ])
            let name = await s.engineName
            let opts = await s.options
            await s.shutdown()
            return [
                expectNotNil(name, "engine name"),
                expect(opts.count >= 2, "应至少有 Threads/Hash option"),
            ]
        } catch {
            return ["handshake threw: \(error)"]
        }
    }

    static func startposBestmoveValid() async -> [String?] {
        guard available else { print("SKIP startposBestmoveValid"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [(name: "Threads", value: "1")])
            let bm = try await s.searchGame(fen: Fen.startpos, moves: [], tc: .movetime(300))
            await s.shutdown()
            let legal = Set(Rules.legalMoves(Fen.parse(Fen.startpos)!).map { $0.uci })
            return [
                expect(legal.contains(bm.uci), "bestmove \(bm.uci) 应 ∈ 合法着法集"),
                expect(bm.uci.count == 4, "bestmove 应为 4 字符 UCI"),
            ]
        } catch {
            return ["threw: \(error)"]
        }
    }

    /// 复刻支招路径：空会话 → start(8线程/512MB) → searchGame(movetime 1500)。
    static func hintPathBestmoveLegal() async -> [String?] {
        guard available else { print("SKIP hintPathBestmoveLegal"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [
                (name: "Threads", value: "8"),
                (name: "Hash", value: "512"),
            ])
            let bm = try await s.searchGame(fen: Fen.startpos, moves: [], tc: .movetime(1500))
            await s.shutdown()
            let legal = Set(Rules.legalMoves(Fen.parse(Fen.startpos)!).map { $0.uci })
            return [
                expect(legal.contains(bm.uci), "支招 bestmove \(bm.uci) 应 ∈ 合法着法集"),
                expect(bm.uci.count == 4, "bestmove 应为 4 字符 UCI"),
            ]
        } catch {
            await s.shutdown()
            return ["hintPath threw: \(error) - \(error.localizedDescription)"]
        }
    }

    static func randomGamesBestmoveLegal() async -> [String?] {
        guard available else { print("SKIP randomGamesBestmoveLegal"); return [] }
        let s = UCISession()
        var failures: [String] = []
        do {
            try await s.start(enginePath: enginePath, options: [(name: "Threads", value: "1")])
            var seed: UInt64 = 0x9E3779B97F4A7C15
            let rng = { () -> Int in
                seed &*= 6364136223846793005
                return Int(truncatingIfNeeded: seed)
            }
            for game in 0..<6 {
                var board = Fen.parse(Fen.startpos)!
                var history: [Move] = []
                for ply in 0..<40 {
                    let legal = Rules.legalMoves(board)
                    if legal.isEmpty { break }
                    let pick = legal[abs(rng()) % legal.count]
                    let bm: Move
                    do {
                        // 固定 startpos 为基础 FEN + 完整 history，走 "position fen ... moves ..." 路径
                        bm = try await s.searchGame(
                            fen: Fen.startpos,
                            moves: history,
                            tc: .depth(1))
                    } catch {
                        failures.append("game \(game) ply \(ply) search threw: \(error)")
                        break
                    }
                    if !legal.contains(bm) {
                        failures.append("game \(game) ply \(ply): bestmove \(bm.uci) ∉ legal")
                    }
                    history.append(pick)  // 实际走随机着，验证引擎仍合法
                    board = board.apply(pick)
                }
            }
            await s.shutdown()
            return failures.map { $0 }
        } catch {
            await s.shutdown()
            return ["start threw: \(error)"]
        }
    }

    static func multiPVProducesLines() async -> [String?] {
        guard available else { print("SKIP multiPVProducesLines"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [(name: "Threads", value: "1")])
            try await s.startAnalysis(fen: Fen.startpos, moves: [], multiPV: 3)
            try await Task.sleep(nanoseconds: 700_000_000)
            let snap = await s.snapshot
            try await s.stopAnalysis()
            await s.shutdown()
            return [
                expect(snap.lines.count >= 2, "MultiPV=3 至少 2 行，实际 \(snap.lines.count)"),
                expect(!(snap.lines.first?.moves.isEmpty ?? true), "首行应含 PV moves"),
            ]
        } catch {
            await s.shutdown()
            return ["threw: \(error)"]
        }
    }

    static func infiniteThenStop() async -> [String?] {
        guard available else { print("SKIP infiniteThenStop"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [(name: "Threads", value: "1")])
            try await s.startAnalysis(fen: Fen.startpos, moves: [], multiPV: 1)
            try await Task.sleep(nanoseconds: 300_000_000)
            try await s.stopAnalysis()  // 必须等 bestmove 到达
            let snap = await s.snapshot
            await s.shutdown()
            return [
                expectNotNil(snap.bestMove, "stop 后应收到 bestmove"),
                expect(snap.lines.first?.depth ?? 0 > 0, "应已算到一定深度"),
            ]
        } catch {
            await s.shutdown()
            return ["threw: \(error)"]
        }
    }

    /// 连续两次搜索（对弈/支招交错场景）：验证单 go 不变量与等待者互不干扰。
    static func consecutiveSearchesLegal() async -> [String?] {
        guard available else { print("SKIP consecutiveSearchesLegal"); return [] }
        let s = UCISession()
        do {
            try await s.start(enginePath: enginePath, options: [(name: "Threads", value: "1")])
            let legal = Set(Rules.legalMoves(Fen.parse(Fen.startpos)!).map { $0.uci })
            let bm1 = try await s.searchGame(fen: Fen.startpos, moves: [], tc: .depth(1))
            let bm2 = try await s.searchGame(fen: Fen.startpos, moves: [], tc: .movetime(300))
            let bm3 = try await s.searchGame(fen: Fen.startpos, moves: [], tc: .depth(1))
            await s.shutdown()
            return [
                expect(legal.contains(bm1.uci), "第一次搜索 \(bm1.uci) 应合法"),
                expect(legal.contains(bm2.uci), "第二次搜索 \(bm2.uci) 应合法"),
                expect(legal.contains(bm3.uci), "第三次搜索 \(bm3.uci) 应合法"),
            ]
        } catch {
            await s.shutdown()
            return ["threw: \(error)"]
        }
    }

    nonisolated(unsafe) static let all: [(String, () async -> [String?])] = [
        ("EngineIntegrationTests.handshake", handshake),
        ("EngineIntegrationTests.startposBestmoveValid", startposBestmoveValid),
        ("EngineIntegrationTests.hintPathBestmoveLegal", hintPathBestmoveLegal),
        ("EngineIntegrationTests.randomGamesBestmoveLegal", randomGamesBestmoveLegal),
        ("EngineIntegrationTests.multiPVProducesLines", multiPVProducesLines),
        ("EngineIntegrationTests.infiniteThenStop", infiniteThenStop),
        ("EngineIntegrationTests.consecutiveSearchesLegal", consecutiveSearchesLegal),
    ]
}
