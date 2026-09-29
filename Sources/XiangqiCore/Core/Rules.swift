import Foundation

/// 规则：合法性（走完己方不被将/王不照面）、状态（被将/绝杀/困毙）。
public enum Rules {

    /// 某格是否被 side 方攻击（伪合法攻击，含照面也算攻击）。
    /// 用反扫：遍历 side 方各子，生成其伪合法走法，看是否含 to。
    public static func isAttacked(_ board: Board, square to: Square, by side: Color) -> Bool {
        for s in 0..<90 {
            let p = board[s]
            guard p != .empty, p.color == side else { continue }
            if attacks(board, from: s, target: to, piece: p) { return true }
        }
        return false
    }

    /// 王对脸：两王同列且中间无子。
    public static func kingsFacing(_ board: Board) -> Bool {
        guard let r = board.kingSquare(.red),
              let b = board.kingSquare(.black) else { return false }
        guard r.file == b.file else { return false }
        let (lo, hi) = r.rank < b.rank ? (r.rank, b.rank) : (b.rank, r.rank)
        for rank in (lo + 1)..<hi {
            if board[Square(file: r.file, rank: rank)] != .empty { return false }
        }
        return true
    }

    /// color 方是否处于将军态（被对方攻击己王，或两王照面）。
    public static func inCheck(_ board: Board, _ color: Color) -> Bool {
        guard let k = board.kingSquare(color) else { return false }
        let foe = color.flipped
        if isAttacked(board, square: k, by: foe) { return true }
        if kingsFacing(board) { return true }
        return false
    }

    /// 合法走法：伪合法走法中，走完后己方不处于将军态。
    public static func legalMoves(_ board: Board) -> [Move] {
        let side = board.sideToMove
        return MoveGenerator.pseudoLegal(board, side: side).filter { move in
            let nb = board.apply(move)
            return !inCheck(nb, side)
        }
    }

    /// 状态：normal / checkmate（绝杀，被将且无解）/ stalemate（困毙，无走法且未被将，被困方输）。
    public enum Status: Equatable {
        case normal
        case checkmate(loser: Color)   // 绝杀：被将死的一方输
        case stalemate(loser: Color)   // 困毙：无走法的一方输
    }

    public static func status(_ board: Board) -> Status {
        let side = board.sideToMove
        let hasMoves = !legalMoves(board).isEmpty
        if hasMoves {
            return .normal
        }
        if inCheck(board, side) {
            return .checkmate(loser: side)
        }
        return .stalemate(loser: side)
    }

    // MARK: - Attack scan

    /// 子 p 站在 from 是否能攻击到 target（含吃子目标同色也算，因为用于判定"是否攻击王"，王的对方唯一）。
    /// 用于反扫 isAttacked，等价于把 target 当落点判定合法性。
    private static func attacks(_ board: Board, from: Square, target: Square, piece p: Piece) -> Bool {
        switch p.type! {
        case .king:
            // 帥/將攻击：九宫内一格直走；另有王对脸由 kingsFacing 单独处理，此处只算普通攻击。
            guard abs(target.file - from.file) + abs(target.rank - from.rank) == 1 else { return false }
            return target.inPalace(p.color!)
        case .advisor:
            guard abs(target.file - from.file) == 1, abs(target.rank - from.rank) == 1 else { return false }
            return target.inPalace(p.color!)
        case .elephant:
            guard abs(target.file - from.file) == 2, abs(target.rank - from.rank) == 2 else { return false }
            let eyeFile = (from.file + target.file) / 2
            let eyeRank = (from.rank + target.rank) / 2
            return target.isOwnSide(p.color!) && board[Square(file: eyeFile, rank: eyeRank)] == .empty
        case .horse:
            return horseAttacks(from, target) && legClear(board, from: from, target: target)
        case .rook:
            return sameLineClear(board, from: from, to: target)
        case .cannon:
            return cannonAttacks(board, from: from, to: target)
        case .pawn:
            return pawnAttacks(from, target, color: p.color!)
        }
    }

    private static func horseAttacks(_ from: Square, _ target: Square) -> Bool {
        let df = target.file - from.file
        let dr = target.rank - from.rank
        return (abs(df) == 1 && abs(dr) == 2) || (abs(df) == 2 && abs(dr) == 1)
    }

    private static func legClear(_ board: Board, from: Square, target: Square) -> Bool {
        let df = target.file - from.file
        let dr = target.rank - from.rank
        let leg: Square
        if abs(dr) == 2 {
            leg = Square(file: from.file, rank: from.rank + dr / 2)
        } else {
            leg = Square(file: from.file + df / 2, rank: from.rank)
        }
        return board[leg] == .empty
    }

    private static func sameLineClear(_ board: Board, from: Square, to: Square) -> Bool {
        guard from != to else { return false }
        let df = to.file - from.file
        let dr = to.rank - from.rank
        guard df == 0 || dr == 0 else { return false }
        let stepFile = df == 0 ? 0 : (df > 0 ? 1 : -1)
        let stepRank = dr == 0 ? 0 : (dr > 0 ? 1 : -1)
        var f = from.file + stepFile
        var r = from.rank + stepRank
        while f != to.file || r != to.rank {
            if board[Square(file: f, rank: r)] != .empty { return false }
            f += stepFile
            r += stepRank
        }
        return true
    }

    private static func cannonAttacks(_ board: Board, from: Square, to: Square) -> Bool {
        guard from != to else { return false }
        let df = to.file - from.file
        let dr = to.rank - from.rank
        guard df == 0 || dr == 0 else { return false }
        let stepFile = df == 0 ? 0 : (df > 0 ? 1 : -1)
        let stepRank = dr == 0 ? 0 : (dr > 0 ? 1 : -1)
        var f = from.file + stepFile
        var r = from.rank + stepRank
        var screen = 0
        while f != to.file || r != to.rank {
            if board[Square(file: f, rank: r)] != .empty { screen += 1 }
            f += stepFile
            r += stepRank
        }
        return screen == 1
    }

    private static func pawnAttacks(_ from: Square, _ target: Square, color: Color) -> Bool {
        let df = target.file - from.file
        let dr = target.rank - from.rank
        let fwd = color.forwardSign
        if df == 0 && dr == fwd { return true }
        let crossed = color == .red ? from.rank >= 5 : from.rank <= 4
        if crossed && dr == 0 && abs(df) == 1 { return true }
        return false
    }
}
