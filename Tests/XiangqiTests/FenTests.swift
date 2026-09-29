import XiangqiCore

enum FenTests {
    static func startposRoundTrip() -> [String?] {
        guard let board = Fen.parse(Fen.startpos) else { return ["startpos parse failed"] }
        return [expectEqual(Fen.serialize(board), Fen.startpos)]
    }

    static func startposSpotChecks() -> [String?] {
        guard let board = Fen.parse(Fen.startpos) else { return ["startpos parse failed"] }
        return [
            expectEqual(board[Square(file: 0, rank: 9)], .blackRook, "a9"),
            expectEqual(board[Square(file: 1, rank: 9)], .blackHorse, "b9"),
            expectEqual(board[Square(file: 4, rank: 9)], .blackKing, "e9"),
            expectEqual(board[Square(file: 8, rank: 9)], .blackRook, "i9"),
            expectEqual(board[Square(file: 1, rank: 7)], .blackCannon, "b8"),
            expectEqual(board[Square(file: 7, rank: 7)], .blackCannon, "h8"),
            expectEqual(board[Square(file: 0, rank: 6)], .blackPawn, "a7"),
            expectEqual(board[Square(file: 4, rank: 6)], .blackPawn, "e7"),
            expectEqual(board[Square(file: 4, rank: 5)], .empty, "e6 empty"),
            expectEqual(board[Square(file: 1, rank: 2)], .redCannon, "b3"),
            expectEqual(board[Square(file: 7, rank: 2)], .redCannon, "h3"),
            expectEqual(board[Square(file: 0, rank: 3)], .redPawn, "a4"),
            expectEqual(board[Square(file: 4, rank: 3)], .redPawn, "e4"),
            expectEqual(board[Square(file: 4, rank: 0)], .redKing, "e1"),
            expectEqual(board[Square(file: 0, rank: 0)], .redRook, "a1"),
            expectEqual(board[Square(file: 8, rank: 0)], .redRook, "i1"),
        ]
    }

    static func boardStandardMatchesFenStartpos() -> [String?] {
        [expectEqual(Fen.parse(Fen.startpos)!, Board.standard())]
    }

    static func customFenRoundTrip() -> [String?] {
        let fen = "4k4/1r7/9/9/9/9/9/9/9/R3K4 w - - 0 1"
        guard let board = Fen.parse(fen) else { return ["custom fen parse failed"] }
        return [
            expectEqual(Fen.serialize(board), fen),
            expectEqual(board.sideToMove, .red),
            expectEqual(board[Square(file: 1, rank: 8)], .blackRook, "b8 rook"),
            expectEqual(board[Square(file: 4, rank: 9)], .blackKing, "e9 king"),
            expectEqual(board[Square(file: 0, rank: 0)], .redRook, "a1 rook"),
            expectEqual(board[Square(file: 4, rank: 0)], .redKing, "e1 king"),
        ]
    }

    static func blackSideToMove() -> [String?] {
        let fen = "4k4/9/9/9/9/9/9/9/4K4/9 b - - 0 1"
        guard let board = Fen.parse(fen) else { return ["parse failed"] }
        return [
            expectEqual(board.sideToMove, .black),
            expectEqual(Fen.serialize(board), fen),
        ]
    }

    static func invalidFenReturnsNil() -> [String?] {
        [
            expectNil(Fen.parse("")),
            expectNil(Fen.parse("9/9/9/9/9/9/9/9/9 w"), "9 行"),
            expectNil(Fen.parse("9/9/9/9/9/9/9/9/9/9/9 w - - 0 1"), "11 行"),
            expectNil(Fen.parse("10/9/9/9/9/9/9/9/9/9 w - - 0 1"), "数字越界"),
            expectNil(Fen.parse("9/9/9/9/9/9/9/9/9/9 x - - 0 1"), "行棋方非法"),
            expectNil(Fen.parse("rnbakabn/9/9/9/9/9/9/9/9/9 w - - 0 1"), "行内不足 9 格"),
        ]
    }

    static func tolerantParseDropsTrailingFields() -> [String?] {
        guard let board = Fen.parse("4k4/9/9/9/9/9/9/9/4K4/9 b") else { return ["parse failed"] }
        return [expectEqual(board.sideToMove, .black)]
    }

    static func twoKingsAdjacentFiles() -> [String?] {
        let fen = "4k4/9/9/9/9/9/9/9/9/3K5 w - - 0 1"
        guard let board = Fen.parse(fen) else { return ["parse failed"] }
        return [expectEqual(Fen.serialize(board), fen)]
    }

    static func squareUciRoundTrip() -> [String?] {
        [
            expectEqual(Square(file: 0, rank: 0).uci, "a0"),
            expectEqual(Square(file: 8, rank: 9).uci, "i9"),
            expectEqual(Square(file: 7, rank: 2).uci, "h2"),
            expectEqual(Square.parse("h2"), Square(file: 7, rank: 2)),
            expectEqual(Square.parse("a0"), Square(file: 0, rank: 0)),
            expectEqual(Square.parse("i9"), Square(file: 8, rank: 9)),
            expectNil(Square.parse("j0")),
            expectNil(Square.parse("a10")),
            expectNil(Square.parse("h")),
        ]
    }

    static func moveUciRoundTrip() -> [String?] {
        let move = Move(from: Square(file: 1, rank: 9), to: Square(file: 2, rank: 7))
        return [
            expectEqual(move.uci, "b9c7"),
            expectEqual(Move.parse("b9c7"), move),
            expectNil(Move.parse("b9c")),
            expectNil(Move.parse("b9c77")),
        ]
    }

    nonisolated(unsafe) static let all: [(String, () -> [String?])] = [
        ("FenTests.startposRoundTrip", startposRoundTrip),
        ("FenTests.startposSpotChecks", startposSpotChecks),
        ("FenTests.boardStandardMatchesFenStartpos", boardStandardMatchesFenStartpos),
        ("FenTests.customFenRoundTrip", customFenRoundTrip),
        ("FenTests.blackSideToMove", blackSideToMove),
        ("FenTests.invalidFenReturnsNil", invalidFenReturnsNil),
        ("FenTests.tolerantParseDropsTrailingFields", tolerantParseDropsTrailingFields),
        ("FenTests.twoKingsAdjacentFiles", twoKingsAdjacentFiles),
        ("FenTests.squareUciRoundTrip", squareUciRoundTrip),
        ("FenTests.moveUciRoundTrip", moveUciRoundTrip),
    ]
}
