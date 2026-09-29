import Foundation

/// 格坐标 0..89：index = rank * 9 + file。
/// file 0..8 = a..i（红方视角左→右），rank 0 = 红方底线，rank 9 = 黑方底线。
/// 屏幕显示时的 Y 翻转只发生在 UI 的 BoardGeometry，Core 层不关心显示方向。
public typealias Square = Int

extension Square {
    public static let squareCount = 90

    @inline(__always)
    public var file: Int { self % 9 }

    @inline(__always)
    public var rank: Int { self / 9 }

    @inline(__always)
    public init(file: Int, rank: Int) {
        self = rank * 9 + file
    }

    /// UCI 点名，如 "h3"、"b9"。
    public var uci: String {
        let letters = Array("abcdefghi")
        return String(letters[file]) + String(rank)
    }

    /// 解析 UCI 点名，如 "b9" -> Square(file: 1, rank: 9)。
    public static func parse(_ s: some StringProtocol) -> Square? {
        let chars = Array(s)
        guard chars.count == 2 else { return nil }
        let f = Int(chars[0].asciiValue ?? 0) - 97
        guard (0...8).contains(f) else { return nil }
        guard let r = chars[1].wholeNumberValue, (0...9).contains(r) else { return nil }
        return Square(file: f, rank: r)
    }

    /// 是否在 color 方的九宫内。
    @inline(__always)
    public func inPalace(_ color: Color) -> Bool {
        guard (3...5).contains(file) else { return false }
        return color == .red ? (0...2).contains(rank) : (7...9).contains(rank)
    }

    /// 是否在 color 方的河界本侧（象不得过河：红 rank<=4，黑 rank>=5）。
    @inline(__always)
    public func isOwnSide(_ color: Color) -> Bool {
        color == .red ? rank <= 4 : rank >= 5
    }
}
