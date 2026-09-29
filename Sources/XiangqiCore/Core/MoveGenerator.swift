import Foundation

/// 伪合法走法生成：不检查走完后己方是否被将军。
/// 全部基于 file/rank 算术（避免 index delta 的跨行回卷坑），
/// 边界与规则约束（宫界/河界/马腿/象眼/炮架）在此层过滤。
public enum MoveGenerator {

    private static let orthoDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let diagDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// 生成 side 方在 board 上的全部伪合法走法。
    public static func pseudoLegal(_ board: Board, side: Color) -> [Move] {
        var out: [Move] = []
        out.reserveCapacity(64)
        for s in 0..<90 {
            let p = board[s]
            guard p != .empty, p.color == side else { continue }
            switch p.type! {
            case .king:    appendKing(board, from: s, into: &out)
            case .advisor: appendAdvisor(board, from: s, into: &out)
            case .elephant: appendElephant(board, from: s, into: &out)
            case .horse:   appendHorse(board, from: s, into: &out)
            case .rook:    appendRook(board, from: s, into: &out)
            case .cannon:  appendCannon(board, from: s, into: &out)
            case .pawn:    appendPawn(board, from: s, into: &out)
            }
        }
        return out
    }

    // MARK: - 帥/將：九宫内一格直走
    private static func appendKing(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        for (df, dr) in orthoDirs {
            let f = from.file + df, r = from.rank + dr
            guard (0...8).contains(f), (0...9).contains(r) else { continue }
            let to = Square(file: f, rank: r)
            guard to.inPalace(color), canLand(board, to: to, color: color) else { continue }
            out.append(Move(from: from, to: to))
        }
    }

    // MARK: - 仕/士：九宫内斜走一格
    private static func appendAdvisor(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        for (df, dr) in diagDirs {
            let f = from.file + df, r = from.rank + dr
            guard (0...8).contains(f), (0...9).contains(r) else { continue }
            let to = Square(file: f, rank: r)
            guard to.inPalace(color), canLand(board, to: to, color: color) else { continue }
            out.append(Move(from: from, to: to))
        }
    }

    // MARK: - 相/象：田字斜走两格，不过河，象眼不堵
    private static func appendElephant(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        for (df, dr) in diagDirs {
            let f = from.file + 2 * df, r = from.rank + 2 * dr
            guard (0...8).contains(f), (0...9).contains(r) else { continue }
            let to = Square(file: f, rank: r)
            guard to.isOwnSide(color) else { continue }
            let eye = Square(file: from.file + df, rank: from.rank + dr)
            guard board[eye] == .empty, canLand(board, to: to, color: color) else { continue }
            out.append(Move(from: from, to: to))
        }
    }

    // MARK: - 馬：日字，马腿不堵
    private static func appendHorse(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        let jumps: [(df: Int, dr: Int)] = [
            (1, 2), (-1, 2), (1, -2), (-1, -2),
            (2, 1), (2, -1), (-2, 1), (-2, -1),
        ]
        for j in jumps {
            let f = from.file + j.df, r = from.rank + j.dr
            guard (0...8).contains(f), (0...9).contains(r) else { continue }
            // 马腿：长轴方向的第一格
            let leg: Square = abs(j.dr) == 2
                ? Square(file: from.file, rank: from.rank + j.dr / 2)
                : Square(file: from.file + j.df / 2, rank: from.rank)
            guard board[leg] == .empty else { continue }
            let to = Square(file: f, rank: r)
            if canLand(board, to: to, color: color) {
                out.append(Move(from: from, to: to))
            }
        }
    }

    // MARK: - 車：直线滑动
    private static func appendRook(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        for (df, dr) in orthoDirs {
            var f = from.file + df, r = from.rank + dr
            while (0...8).contains(f), (0...9).contains(r) {
                let to = Square(file: f, rank: r)
                let t = board[to]
                if t == .empty {
                    out.append(Move(from: from, to: to))
                } else {
                    if t.color != color { out.append(Move(from: from, to: to)) }
                    break
                }
                f += df; r += dr
            }
        }
    }

    // MARK: - 炮：空格直走；吃子须隔一枚炮架
    private static func appendCannon(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        for (df, dr) in orthoDirs {
            var f = from.file + df, r = from.rank + dr
            var jumped = false
            while (0...8).contains(f), (0...9).contains(r) {
                let to = Square(file: f, rank: r)
                let t = board[to]
                if !jumped {
                    if t == .empty {
                        out.append(Move(from: from, to: to))
                    } else {
                        jumped = true
                    }
                } else if t != .empty {
                    if t.color != color { out.append(Move(from: from, to: to)) }
                    break
                }
                f += df; r += dr
            }
        }
    }

    // MARK: - 兵/卒：未过河只进；过河加横走
    private static func appendPawn(_ board: Board, from: Square, into out: inout [Move]) {
        let color = board[from].color!
        let fwd = color.forwardSign
        let r1 = from.rank + fwd
        if (0...9).contains(r1) {
            let to = Square(file: from.file, rank: r1)
            if canLand(board, to: to, color: color) {
                out.append(Move(from: from, to: to))
            }
        }
        let crossed = color == .red ? from.rank >= 5 : from.rank <= 4
        if crossed {
            for df in [-1, 1] {
                let f = from.file + df
                guard (0...8).contains(f) else { continue }
                let to = Square(file: f, rank: from.rank)
                if canLand(board, to: to, color: color) {
                    out.append(Move(from: from, to: to))
                }
            }
        }
    }

    // MARK: - helpers

    /// 落点为空或敌子。
    @inline(__always)
    private static func canLand(_ board: Board, to: Square, color: Color) -> Bool {
        let t = board[to]
        return t == .empty || t.color != color
    }
}
