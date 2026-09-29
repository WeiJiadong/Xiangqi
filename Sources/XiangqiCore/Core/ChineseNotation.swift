import Foundation

/// 中文纵线记谱：红用汉字线号（a=九 … i=一），黑用阿拉伯（a=9 … i=1）。
/// 同线同种 ≥2 子用 前/中/后 前缀替代线号（前 = 更靠近敌方）。
/// 平 = 横走（目标线号）；进/退：直线兵种用步数，斜走兵种（马相仕）用目标线号。
public enum ChineseNotation {

    private static let cnNumerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 记谱用字（简体标准）：红 帅仕相马车炮兵 / 黑 将士象马车炮卒。
    private static func notationChar(_ piece: Piece) -> String {
        switch piece {
        case .redKing: return "帅"
        case .redAdvisor: return "仕"
        case .redElephant: return "相"
        case .redHorse: return "马"
        case .redRook: return "车"
        case .redCannon: return "炮"
        case .redPawn: return "兵"
        case .blackKing: return "将"
        case .blackAdvisor: return "士"
        case .blackElephant: return "象"
        case .blackHorse: return "马"
        case .blackRook: return "车"
        case .blackCannon: return "炮"
        case .blackPawn: return "卒"
        case .empty: return ""
        }
    }

    /// 走子前局面 + 走法 -> 记谱字符串，如 "炮二平五"。
    public static func notation(_ board: Board, _ move: Move) -> String {
        let piece = board[move.from]
        return moveBody(board, move, piece: piece)
    }

    /// 从局面开始逐步翻译整条 PV。
    public static func translate(_ board: Board, moves: [Move]) -> [String] {
        var b = board
        var out: [String] = []
        out.reserveCapacity(moves.count)
        for m in moves {
            out.append(notation(b, m))
            b = b.apply(m)
        }
        return out
    }

    // MARK: - internals

    private static func moveBody(_ board: Board, _ move: Move, piece: Piece) -> String {
        let color = piece.color!
        let from = move.from
        let to = move.to
        let pieceChar = notationChar(piece)
        let dr = to.rank - from.rank
        let isDiagonal = switch piece.type! {
        case .horse, .elephant, .advisor: true
        case .king, .rook, .cannon, .pawn: false
        }

        let head: String
        if let pfx = disambiguationPrefix(board, from, piece: piece) {
            // 前/中/后 前缀置于棋子前
            head = "\(pfx)\(pieceChar)"
        } else {
            // 无前缀：源线号置于棋子后
            head = "\(pieceChar)\(fileNum(color, from.file))"
        }

        if dr == 0 {
            return "\(head)平\(fileNum(color, to.file))"
        }
        let forward = color == .red ? dr > 0 : dr < 0
        let verb = forward ? "进" : "退"
        let tail = isDiagonal ? fileNum(color, to.file) : stepNum(color, abs(dr))
        return "\(head)\(verb)\(tail)"
    }

    /// 同线（同 from.file）同色同种 ≥2 子时返回 前/中/后/序号 前缀；否则返回 nil 用源线号。
    private static func disambiguationPrefix(_ board: Board, _ from: Square, piece: Piece) -> String? {
        let color = piece.color!
        var sameFile: [Square] = []
        for rank in 0..<10 where board[Square(file: from.file, rank: rank)] == piece {
            sameFile.append(Square(file: from.file, rank: rank))
        }
        guard sameFile.count >= 2 else { return nil }
        // 前 = 更靠近敌方：红 rank 大在前，黑 rank 小在前
        let sorted = sameFile.sorted { color == .red ? $0.rank > $1.rank : $0.rank < $1.rank }
        guard let idx = sorted.firstIndex(of: from) else { return nil }
        return positionLabel(color, idx: idx, count: sorted.count)
    }

    /// idx=0 为前，idx=count-1 为后；3 子中间为中；更多子按位次编号（二三四…）。
    private static func positionLabel(_ color: Color, idx: Int, count: Int) -> String {
        if idx == 0 { return "前" }
        if idx == count - 1 { return "后" }
        if count == 3 { return "中" }
        return color == .red ? cnNumerals[idx] : String(idx + 1)
    }

    /// 线号：红汉字 / 黑阿拉伯，双方均为 9 - file。
    private static func fileNum(_ color: Color, _ file: Int) -> String {
        color == .red ? cnNumerals[8 - file] : String(9 - file)
    }

    /// 步数：红汉字 / 黑阿拉伯。
    private static func stepNum(_ color: Color, _ steps: Int) -> String {
        color == .red ? cnNumerals[steps - 1] : String(steps)
    }
}
