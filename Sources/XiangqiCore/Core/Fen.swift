import Foundation

/// FEN 解析与序列化。
/// 标准象棋 FEN：6 字段 `rnbakabnr/.../... w - - 0 1`。
/// 序列化始终输出 6 字段；解析时容忍省略后三个字段。
public enum Fen {
    public static let startpos = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    public static func parse(_ fen: String) -> Board? {
        let parts = fen.split(separator: " ", omittingEmptySubsequences: false)
        guard let placement = parts.first, parts.count >= 2 else { return nil }
        let rows = placement.split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 10 else { return nil }

        var board = Board()
        // FEN 首段是 rank 9（黑底线）向下到 rank 0。
        for (rowIdx, row) in rows.enumerated() {
            let rank = 9 - rowIdx
            var file = 0
            for ch in row {
                if let n = ch.wholeNumberValue, (1...9).contains(n) {
                    file += n
                    continue
                }
                guard file < 9,
                      let piece = Piece(fenChar: ch)
                else { return nil }
                board[Square(file: file, rank: rank)] = piece
                file += 1
            }
            guard file == 9 else { return nil }
        }

        let sideStr = String(parts[1])
        guard sideStr == "w" || sideStr == "b" else { return nil }
        board.sideToMove = sideStr == "w" ? .red : .black
        // 后续字段（castling/enpassant/halfmove/fullmove）解析忽略。
        return board
    }

    public static func serialize(_ board: Board) -> String {
        var rows: [String] = []
        for rank in stride(from: 9, through: 0, by: -1) {
            var row = ""
            var empties = 0
            for file in 0..<9 {
                let p = board[Square(file: file, rank: rank)]
                if p == .empty {
                    empties += 1
                } else {
                    if empties > 0 { row += String(empties); empties = 0 }
                    row.append(p.fenChar)
                }
            }
            if empties > 0 { row += String(empties) }
            rows.append(row)
        }
        let placement = rows.joined(separator: "/")
        let side = board.sideToMove == .red ? "w" : "b"
        return "\(placement) \(side) - - 0 1"
    }
}
