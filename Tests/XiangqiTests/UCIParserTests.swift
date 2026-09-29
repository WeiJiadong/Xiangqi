import XiangqiCore

enum UCIParserTests {
    static func infoCpMultiPV() -> [String?] {
        let line = "info depth 8 seldepth 12 multipv 2 score cp -35 nodes 9876 nps 456789 time 217 pv b9c7 h2e2"
        guard case .info(let l)? = UCIParser.parseLine(line) else { return ["info line not parsed"] }
        return [
            expectEqual(l.depth, 8),
            expectEqual(l.seldepth, 12),
            expectEqual(l.multipv, 2),
            expectEqual(l.score, Score.cp(-35)),
            expectEqual(l.nodes, Int64(9876)),
            expectEqual(l.nps, Int64(456789)),
            expectEqual(l.timeMs, Int64(217)),
            expectEqual(l.pv.map { $0.uci }, ["b9c7", "h2e2"]),
            expect(!l.lowerbound && !l.upperbound),
        ]
    }

    static func infoMatePositive() -> [String?] {
        guard case .info(let l)? = UCIParser.parseLine("info depth 5 score mate 3 pv h2e2 e6e5") else {
            return ["not parsed"]
        }
        return [expectEqual(l.score, Score.mate(3))]
    }

    static func infoMateNegative() -> [String?] {
        guard case .info(let l)? = UCIParser.parseLine("info depth 6 score mate -2 pv a1a2") else {
            return ["not parsed"]
        }
        return [expectEqual(l.score, Score.mate(-2))]
    }

    static func infoLowerbound() -> [String?] {
        guard case .info(let l)? = UCIParser.parseLine("info depth 4 score cp 12 lowerbound") else {
            return ["not parsed"]
        }
        return [
            expect(l.lowerbound),
            expectEqual(l.score, Score.cp(12)),
            expectEqual(l.pv.count, 0),
        ]
    }

    static func infoWithoutScore() -> [String?] {
        guard case .info(let l)? = UCIParser.parseLine("info depth 1 nodes 42") else {
            return ["not parsed"]
        }
        return [
            expectNil(l.score),
            expectEqual(l.depth, 1),
            expectEqual(l.nodes, Int64(42)),
        ]
    }

    static func bestmoveWithPonder() -> [String?] {
        guard case .bestmove(let mv, let ponder)? = UCIParser.parseLine("bestmove h2e2 ponder b9c7") else {
            return ["not parsed"]
        }
        return [
            expectEqual(mv, Move.parse("h2e2")),
            expectEqual(ponder, Move.parse("b9c7")),
        ]
    }

    static func bestmoveBare() -> [String?] {
        guard case .bestmove(let mv, let ponder)? = UCIParser.parseLine("bestmove a0a1") else {
            return ["not parsed"]
        }
        return [
            expectEqual(mv, Move.parse("a0a1")),
            expectNil(ponder),
        ]
    }

    static func bestmoveNone() -> [String?] {
        guard case .bestmove(let mv, _)? = UCIParser.parseLine("bestmove (none)") else {
            return ["not parsed"]
        }
        return [expectNil(mv)]
    }

    static func idLines() -> [String?] {
        guard case .idName(let n)? = UCIParser.parseLine("id name Pikafish dev") else {
            return ["id name not parsed"]
        }
        guard case .idAuthor(let a)? = UCIParser.parseLine("id author Pikafish Team") else {
            return ["id author not parsed"]
        }
        return [expectEqual(n, "Pikafish dev"), expectEqual(a, "Pikafish Team")]
    }

    static func optionSpin() -> [String?] {
        guard case .option(let o)? = UCIParser.parseLine("option name Hash type spin default 16 min 1 max 1024") else {
            return ["option not parsed"]
        }
        guard case .spin(let def, let mn, let mx) = o.kind else { return ["kind not spin"] }
        return [expectEqual(o.name, "Hash"), expectEqual(def, 16), expectEqual(mn, 1), expectEqual(mx, 1024)]
    }

    static func optionString() -> [String?] {
        guard case .option(let o)? = UCIParser.parseLine("option name EvalFile type string default nn.nnue") else {
            return ["option not parsed"]
        }
        guard case .string(let def) = o.kind else { return ["kind not string"] }
        return [expectEqual(o.name, "EvalFile"), expectEqual(def, "nn.nnue")]
    }

    static func simpleEvents() -> [String?] {
        return [
            expectEqual(UCIParser.parseLine("uciok"), UCIEvent.uciok),
            expectEqual(UCIParser.parseLine("readyok"), UCIEvent.readyok),
            expectNil(UCIParser.parseLine("")),
            expectNil(UCIParser.parseLine("garbage tokens here")),
        ]
    }

    nonisolated(unsafe) static let all: [(String, () -> [String?])] = [
        ("UCIParserTests.infoCpMultiPV", infoCpMultiPV),
        ("UCIParserTests.infoMatePositive", infoMatePositive),
        ("UCIParserTests.infoMateNegative", infoMateNegative),
        ("UCIParserTests.infoLowerbound", infoLowerbound),
        ("UCIParserTests.infoWithoutScore", infoWithoutScore),
        ("UCIParserTests.bestmoveWithPonder", bestmoveWithPonder),
        ("UCIParserTests.bestmoveBare", bestmoveBare),
        ("UCIParserTests.bestmoveNone", bestmoveNone),
        ("UCIParserTests.idLines", idLines),
        ("UCIParserTests.optionSpin", optionSpin),
        ("UCIParserTests.optionString", optionString),
        ("UCIParserTests.simpleEvents", simpleEvents),
    ]
}
