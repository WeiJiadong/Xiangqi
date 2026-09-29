import Foundation

/// 一步走法：from -> to。捕获信息在 apply 时根据目标格派生，不在此缓存。
public struct Move: Hashable, Sendable, CustomStringConvertible {
    public let from: Square
    public let to: Square

    public init(from: Square, to: Square) {
        self.from = from
        self.to = to
    }

    /// UCI 走法字符串，如 "b9c7"。
    public var uci: String { from.uci + to.uci }

    /// 解析 UCI 走法字符串 "b9c7" -> Move。
    public static func parse(_ s: some StringProtocol) -> Move? {
        let chars = Array(s)
        guard chars.count == 4,
              let from = Square.parse(String(chars[0..<2])),
              let to = Square.parse(String(chars[2..<4]))
        else { return nil }
        return Move(from: from, to: to)
    }

    public var description: String { uci }
}
