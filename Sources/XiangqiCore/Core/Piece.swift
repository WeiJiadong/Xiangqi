import Foundation

public enum Color: UInt8, Sendable, Hashable {
    case red = 0
    case black = 1

    public var flipped: Color { self == .red ? .black : .red }

    /// 行棋方向：红方向 rank 增大，黑方向 rank 减小。
    public var forwardSign: Int { self == .red ? 1 : -1 }
}

public enum PieceType: UInt8, Sendable, Hashable, CaseIterable {
    case king = 0, advisor, elephant, horse, rook, cannon, pawn
}

/// 棋子打包进 UInt8：0=空，1..7=红 K/A/B/H/R/C/P，8..14=黑对应。
public enum Piece: UInt8, Sendable, Hashable {
    case empty = 0
    case redKing = 1, redAdvisor, redElephant, redHorse, redRook, redCannon, redPawn
    case blackKing = 8, blackAdvisor, blackElephant, blackHorse, blackRook, blackCannon, blackPawn

    public var color: Color? {
        switch self {
        case .empty: return nil
        case .redKing, .redAdvisor, .redElephant, .redHorse, .redRook, .redCannon, .redPawn: return .red
        case .blackKing, .blackAdvisor, .blackElephant, .blackHorse, .blackRook, .blackCannon, .blackPawn: return .black
        }
    }

    public var type: PieceType? {
        switch self {
        case .empty: return nil
        case .redKing, .blackKing: return .king
        case .redAdvisor, .blackAdvisor: return .advisor
        case .redElephant, .blackElephant: return .elephant
        case .redHorse, .blackHorse: return .horse
        case .redRook, .blackRook: return .rook
        case .redCannon, .blackCannon: return .cannon
        case .redPawn, .blackPawn: return .pawn
        }
    }

    /// 棋盘字形：红 帥仕相馬車炮兵，黑 將士象馬車砲卒（记谱标准用字）。
    public var glyph: String {
        switch self {
        case .empty: return ""
        case .redKing: return "帥"
        case .redAdvisor: return "仕"
        case .redElephant: return "相"
        case .redHorse: return "馬"
        case .redRook: return "車"
        case .redCannon: return "炮"
        case .redPawn: return "兵"
        case .blackKing: return "將"
        case .blackAdvisor: return "士"
        case .blackElephant: return "象"
        case .blackHorse: return "馬"
        case .blackRook: return "車"
        case .blackCannon: return "砲"
        case .blackPawn: return "卒"
        }
    }

    /// FEN 字符：红大写 K A B N R C P，黑小写。
    public var fenChar: Character {
        switch self {
        case .empty: return "."
        case .redKing: return "K"
        case .redAdvisor: return "A"
        case .redElephant: return "B"
        case .redHorse: return "N"
        case .redRook: return "R"
        case .redCannon: return "C"
        case .redPawn: return "P"
        case .blackKing: return "k"
        case .blackAdvisor: return "a"
        case .blackElephant: return "b"
        case .blackHorse: return "n"
        case .blackRook: return "r"
        case .blackCannon: return "c"
        case .blackPawn: return "p"
        }
    }

    public init?(fenChar c: Character) {
        switch c {
        case "K": self = .redKing
        case "A": self = .redAdvisor
        case "B": self = .redElephant
        case "N": self = .redHorse
        case "R": self = .redRook
        case "C": self = .redCannon
        case "P": self = .redPawn
        case "k": self = .blackKing
        case "a": self = .blackAdvisor
        case "b": self = .blackElephant
        case "n": self = .blackHorse
        case "r": self = .blackRook
        case "c": self = .blackCannon
        case "p": self = .blackPawn
        default: return nil
        }
    }
}
