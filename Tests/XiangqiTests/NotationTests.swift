import XiangqiCore

enum NotationTests {
    static func startposCannonH2E2() -> [String?] {
        let b = Fen.parse(Fen.startpos)!
        let m = Move.parse("h2e2")!
        return [expectEqual(ChineseNotation.notation(b, m), "炮二平五")]
    }

    static func startposHorseB9C7() -> [String?] {
        // 黑方先行：构造黑方走 b9c7
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("b9c7")!
        return [expectEqual(ChineseNotation.notation(b, m), "马8进7")]
    }

    static func startposPawnG3G4() -> [String?] {
        let b = Fen.parse(Fen.startpos)!
        let m = Move.parse("g3g4")!
        return [expectEqual(ChineseNotation.notation(b, m), "兵三进一")]
    }

    static func blackCannonH7E7() -> [String?] {
        // 黑方先行：黑炮 h7(file7,rank7) 平到 e7(file4)
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("h7e7")!
        return [expectEqual(ChineseNotation.notation(b, m), "炮2平5")]
    }

    static func redAdvisorD0E1() -> [String?] {
        // 红仕 d0(file3,rank0) -> e1(file4,rank1)：仕六进五
        let b = Fen.parse(Fen.startpos)!
        let m = Move.parse("d0e1")!
        return [expectEqual(ChineseNotation.notation(b, m), "仕六进五")]
    }

    static func redElephantA2C4() -> [String?] {
        // 红相 a2(file0,rank2) -> c4(file2,rank4)：相九进七；黑将置 d9 避免王照面
        let fen = "3k5/9/9/9/9/9/9/B8/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("a2c4")!
        return [expectEqual(ChineseNotation.notation(b, m), "相九进七")]
    }

    static func rookStraightSteps() -> [String?] {
        // 红车 a0(file0,rank0) -> a3(file0,rank3)：车九进三
        let fen = "3k5/9/9/9/9/9/9/9/9/R3K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("a0a3")!
        return [expectEqual(ChineseNotation.notation(b, m), "车九进三")]
    }

    static func rookHorizontal() -> [String?] {
        // 红车 a0 -> b0：车九平八
        let fen = "3k5/9/9/9/9/9/9/9/9/R3K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("a0b0")!
        return [expectEqual(ChineseNotation.notation(b, m), "车九平八")]
    }

    static func twoRooksSameFileFrontRear() -> [String?] {
        // 红车 a0 / a4 同线：前=a4(rank4)。a4->a5 前车进一；a0->a1 后车进一
        let fen = "3k5/9/9/9/9/R8/9/9/9/R3K4 w - - 0 1"
        let b = Fen.parse(fen)!
        return [
            expectEqual(ChineseNotation.notation(b, Move.parse("a4a5")!), "前车进一"),
            expectEqual(ChineseNotation.notation(b, Move.parse("a0a1")!), "后车进一"),
            expectEqual(ChineseNotation.notation(b, Move.parse("a4b4")!), "前车平八"),
        ]
    }

    static func threePawnsSameFile() -> [String?] {
        // 红兵 a3/a4/a5 同线：前=a5 中=a4 后=a3
        // 黑将置 d9 避免王照面
        let fen = "3k5/9/9/9/P8/P8/P8/9/9/3K5 w - - 0 1"
        let b = Fen.parse(fen)!
        return [
            expectEqual(ChineseNotation.notation(b, Move.parse("a5a6")!), "前兵进一"),
            expectEqual(ChineseNotation.notation(b, Move.parse("a4a5")!), "中兵进一"),
            expectEqual(ChineseNotation.notation(b, Move.parse("a3a4")!), "后兵进一"),
        ]
    }

    static func twoPawnsSameFile() -> [String?] {
        let fen = "3k5/9/9/9/9/P8/P8/9/9/3K5 w - - 0 1"
        let b = Fen.parse(fen)!
        return [
            expectEqual(ChineseNotation.notation(b, Move.parse("a4a5")!), "前兵进一"),
            expectEqual(ChineseNotation.notation(b, Move.parse("a3a4")!), "后兵进一"),
        ]
    }

    static func kingMove() -> [String?] {
        // 红帅 e0 -> e1：帅五进一
        let fen = "3k5/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("e0e1")!
        return [expectEqual(ChineseNotation.notation(b, m), "帅五进一")]
    }

    static func blackPawnForward() -> [String?] {
        // 黑卒 e6(file4,rank6) -> e5(file4,rank5)：黑进（dr=-1），线号 9-4=5，步数 1
        let fen = "4k4/9/9/4p4/9/9/9/9/9/3K5 b - - 0 1"
        let b = Fen.parse(fen)!
        let m = Move.parse("e6e5")!
        return [expectEqual(ChineseNotation.notation(b, m), "卒5进1")]
    }

    static func translatePV() -> [String?] {
        let b = Fen.parse(Fen.startpos)!
        let moves = [Move.parse("h2e2")!, Move.parse("b9c7")!]
        let pv = ChineseNotation.translate(b, moves: moves)
        return [
            expectEqual(pv.count, 2),
            expectEqual(pv[0], "炮二平五"),
            expectEqual(pv[1], "马8进7"),
        ]
    }

    nonisolated(unsafe) static let all: [(String, () -> [String?])] = [
        ("NotationTests.startposCannonH2E2", startposCannonH2E2),
        ("NotationTests.startposHorseB9C7", startposHorseB9C7),
        ("NotationTests.startposPawnG3G4", startposPawnG3G4),
        ("NotationTests.blackCannonH7E7", blackCannonH7E7),
        ("NotationTests.redAdvisorD0E1", redAdvisorD0E1),
        ("NotationTests.redElephantA2C4", redElephantA2C4),
        ("NotationTests.rookStraightSteps", rookStraightSteps),
        ("NotationTests.rookHorizontal", rookHorizontal),
        ("NotationTests.twoRooksSameFileFrontRear", twoRooksSameFileFrontRear),
        ("NotationTests.threePawnsSameFile", threePawnsSameFile),
        ("NotationTests.twoPawnsSameFile", twoPawnsSameFile),
        ("NotationTests.kingMove", kingMove),
        ("NotationTests.blackPawnForward", blackPawnForward),
        ("NotationTests.translatePV", translatePV),
    ]
}
