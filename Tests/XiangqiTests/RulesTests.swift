import XiangqiCore

enum RulesTests {
    static func perftStartposAnchors() -> [String?] {
        let b = Fen.parse(Fen.startpos)!
        return [
            expectEqual(Perft.count(b, depth: 1), 44, "perft d1"),
            expectEqual(Perft.count(b, depth: 2), 1920, "perft d2"),
        ]
    }

    static func perftDepth3() -> [String?] {
        let b = Fen.parse(Fen.startpos)!
        return [expectEqual(Perft.count(b, depth: 3), 79666, "perft d3")]
    }

    static func kingsFacing() -> [String?] {
        let fen = "4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        return [
            expect(Rules.kingsFacing(b), "同列无遮挡应照面"),
            expect(Rules.inCheck(b, .red), "红方被照面视为被将"),
            expect(Rules.inCheck(b, .black), "黑方被照面视为被将"),
        ]
    }

    static func kingsNotFacingWithScreen() -> [String?] {
        let fen = "4k4/9/9/9/4P4/9/9/9/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        return [expect(!Rules.kingsFacing(b), "有子遮挡不照面")]
    }

    static func horseLegBlocked() -> [String?] {
        // 红马 b0(file1,rank0)，黑卒 b1(file1,rank1) 堵腿 -> a2/c2 不可达
        let fen = "4k4/9/9/9/9/9/9/9/1p7/1N7 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 1, rank: 0)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(!targets.contains(Square(file: 0, rank: 2)), "马腿被堵不可跳 a2"),
            expect(!targets.contains(Square(file: 2, rank: 2)), "马腿被堵不可跳 c2"),
            expect(targets.contains(Square(file: 3, rank: 1)), "横跳 d1 不受 b1 腿影响"),
        ]
    }

    static func horseLegOpen() -> [String?] {
        let fen = "4k4/9/9/9/9/9/9/9/9/1N7 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 1, rank: 0)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(targets.contains(Square(file: 0, rank: 2)), "马腿无堵可跳 a2"),
            expect(targets.contains(Square(file: 2, rank: 2)), "马腿无堵可跳 c2"),
        ]
    }

    static func elephantEyeBlocked() -> [String?] {
        // 红相 e1(file4,rank1)，象眼 d2(file3,rank2) 被黑卒占 -> c3 不可达；
        // 黑将置 d9 避开 e 列王照面，使相移走后红不被将
        let fen = "3k5/9/9/9/9/9/9/3p5/4B4/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 4, rank: 1)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(!targets.contains(Square(file: 2, rank: 3)), "象眼被堵不可到 c3"),
            expect(targets.contains(Square(file: 6, rank: 3)), "象眼通畅可到 g3"),
        ]
    }

    static func pawnCrossRiver() -> [String?] {
        // 红兵 e5(file4,rank5) 已过河：可前/左/右；黑将置 d9 避免王照面干扰
        let fen = "3k5/9/9/9/4P4/9/9/9/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 4, rank: 5)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(targets.contains(Square(file: 4, rank: 6)), "过河兵可前进"),
            expect(targets.contains(Square(file: 3, rank: 5)), "过河兵可横走"),
            expect(targets.contains(Square(file: 5, rank: 5)), "过河兵可横走"),
        ]
    }

    static func pawnBeforeRiver() -> [String?] {
        // 红兵 e4(file4,rank4) 未过河：只能前进
        let fen = "4k4/9/9/9/9/4P4/9/9/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 4, rank: 4)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(targets.contains(Square(file: 4, rank: 5)), "未过河兵可前进"),
            expect(!targets.contains(Square(file: 3, rank: 4)), "未过河兵不可横走"),
        ]
    }

    static func cannonNeedsScreen() -> [String?] {
        // 红炮 b2，黑卒 b6 作炮架，黑马 b7 可隔架吃；黑将放 a9 避免王照面
        let fen = "k8/9/1n7/1p7/9/9/9/1C7/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let from = Square(file: 1, rank: 2)
        let targets = Rules.legalMoves(b).filter { $0.from == from }.map { $0.to }
        return [
            expect(targets.contains(Square(file: 1, rank: 7)), "隔一炮架可吃 b7 马"),
            expect(!targets.contains(Square(file: 1, rank: 6)), "炮架本身不可被吃"),
            expect(targets.contains(Square(file: 2, rank: 2)), "炮空格可直走 c2"),
        ]
    }

    static func checkmatePosition() -> [String?] {
        // 双车错杀：红车 a9 + 红车 e8（被 e0 车防守），黑将 e9 无路
        let fen = "R3k4/4R4/9/9/9/9/9/9/9/3KR4 b - - 0 1"
        let b = Fen.parse(fen)!
        return [expectEqual(Rules.status(b), .checkmate(loser: .black), "应为绝杀，黑负")]
    }

    static func stalematePosition() -> [String?] {
        // 困毙：黑将 e9；红兵 d8 控 d9，红兵 f8 控 f9，两兵共同控 e8；黑未被将但无路
        let fen = "4k4/3P1P3/9/9/9/9/9/9/9/3K5 b - - 0 1"
        let b = Fen.parse(fen)!
        return [expectEqual(Rules.status(b), .stalemate(loser: .black), "应为困毙，黑负")]
    }

    static func applyFlipsSide() -> [String?] {
        let b = Board.standard()
        let m = Move(from: Square(file: 1, rank: 2), to: Square(file: 4, rank: 2)) // 炮二平五
        let nb = b.apply(m)
        return [
            expectEqual(nb.sideToMove, .black),
            expectEqual(nb[Square(file: 4, rank: 2)], .redCannon),
            expectEqual(nb[Square(file: 1, rank: 2)], .empty),
            expectEqual(b.sideToMove, .red, "原局面不变 copy-make"),
        ]
    }

    nonisolated(unsafe) static let all: [(String, () -> [String?])] = [
        ("RulesTests.perftStartposAnchors", perftStartposAnchors),
        ("RulesTests.perftDepth3", perftDepth3),
        ("RulesTests.kingsFacing", kingsFacing),
        ("RulesTests.kingsNotFacingWithScreen", kingsNotFacingWithScreen),
        ("RulesTests.horseLegBlocked", horseLegBlocked),
        ("RulesTests.horseLegOpen", horseLegOpen),
        ("RulesTests.elephantEyeBlocked", elephantEyeBlocked),
        ("RulesTests.pawnCrossRiver", pawnCrossRiver),
        ("RulesTests.pawnBeforeRiver", pawnBeforeRiver),
        ("RulesTests.cannonNeedsScreen", cannonNeedsScreen),
        ("RulesTests.checkmatePosition", checkmatePosition),
        ("RulesTests.stalematePosition", stalematePosition),
        ("RulesTests.applyFlipsSide", applyFlipsSide),
    ]
}
