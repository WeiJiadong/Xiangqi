import Foundation

/// 局面：90 格棋盘 + 行棋方。值类型，copy-make 走子。
public struct Board: Sendable, Hashable {
    public var squares: ContiguousArray<Piece>
    public var sideToMove: Color

    public init(squares: ContiguousArray<Piece> = ContiguousArray(repeating: .empty, count: 90),
                sideToMove: Color = .red) {
        self.squares = squares
        self.sideToMove = sideToMove
    }

    public subscript(_ s: Square) -> Piece {
        get { squares[s] }
        set { squares[s] = newValue }
    }

    /// 起始局面。
    public static func standard() -> Board {
        // rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w
        var b = Board()
        b[Square(file: 0, rank: 9)] = .blackRook
        b[Square(file: 1, rank: 9)] = .blackHorse
        b[Square(file: 2, rank: 9)] = .blackElephant
        b[Square(file: 3, rank: 9)] = .blackAdvisor
        b[Square(file: 4, rank: 9)] = .blackKing
        b[Square(file: 5, rank: 9)] = .blackAdvisor
        b[Square(file: 6, rank: 9)] = .blackElephant
        b[Square(file: 7, rank: 9)] = .blackHorse
        b[Square(file: 8, rank: 9)] = .blackRook
        b[Square(file: 1, rank: 7)] = .blackCannon
        b[Square(file: 7, rank: 7)] = .blackCannon
        for f in [0, 2, 4, 6, 8] { b[Square(file: f, rank: 6)] = .blackPawn }

        b[Square(file: 0, rank: 0)] = .redRook
        b[Square(file: 1, rank: 0)] = .redHorse
        b[Square(file: 2, rank: 0)] = .redElephant
        b[Square(file: 3, rank: 0)] = .redAdvisor
        b[Square(file: 4, rank: 0)] = .redKing
        b[Square(file: 5, rank: 0)] = .redAdvisor
        b[Square(file: 6, rank: 0)] = .redElephant
        b[Square(file: 7, rank: 0)] = .redHorse
        b[Square(file: 8, rank: 0)] = .redRook
        b[Square(file: 1, rank: 2)] = .redCannon
        b[Square(file: 7, rank: 2)] = .redCannon
        for f in [0, 2, 4, 6, 8] { b[Square(file: f, rank: 3)] = .redPawn }

        b.sideToMove = .red
        return b
    }

    /// copy-make 走子：拷贝、移子、清 from、翻行棋方。不校验合法性。
    public func apply(_ move: Move) -> Board {
        var nb = self
        nb[move.to] = nb[move.from]
        nb[move.from] = .empty
        nb.sideToMove = sideToMove.flipped
        return nb
    }

    /// 找 color 方的帅/将格。
    public func kingSquare(_ color: Color) -> Square? {
        let target: Piece = color == .red ? .redKing : .blackKing
        for s in 0..<90 where squares[s] == target {
            return s
        }
        return nil
    }
}
