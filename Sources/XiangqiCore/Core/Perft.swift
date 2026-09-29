import Foundation

/// Perft：从局面递归走合法走法的叶节点计数，作为规则正确性的金标准。
public enum Perft {
    public static func count(_ board: Board, depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = Rules.legalMoves(board)
        if depth == 1 { return moves.count }
        var n = 0
        for m in moves {
            n += count(board.apply(m), depth: depth - 1)
        }
        return n
    }

    /// divide：输出每条根走法下的子树节点数，便于与引擎对拍定位。
    public static func divide(_ board: Board, depth: Int) -> [(Move, Int)] {
        Rules.legalMoves(board).map { m in
            (m, count(board.apply(m), depth: depth - 1))
        }.sorted { $0.0.uci < $1.0.uci }
    }
}
