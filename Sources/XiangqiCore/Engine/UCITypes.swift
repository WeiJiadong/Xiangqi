import Foundation

/// UCI 评分：行棋方视角。cp = 厘兵；mate n > 0 = 行棋方 n 步内杀，< 0 = 行棋方 n 步内被杀。
public enum Score: Equatable, Sendable {
    case cp(Int)
    case mate(Int)
}

/// 单条 PV 行（MultiPV 按行区分）。
public struct PvLine: Equatable, Sendable {
    public var multipv: Int
    public var depth: Int?
    public var score: Score?
    public var moves: [Move]

    public init(multipv: Int, depth: Int? = nil, score: Score? = nil, moves: [Move] = []) {
        self.multipv = multipv
        self.depth = depth
        self.score = score
        self.moves = moves
    }
}

/// 引擎分析快照：UI 轮询读取。
public struct AnalysisSnapshot: Equatable, Sendable {
    public var depth: Int
    public var nodes: Int64
    public var nps: Int64
    public var lines: [PvLine]
    public var bestMove: Move?

    public init(depth: Int = 0, nodes: Int64 = 0, nps: Int64 = 0, lines: [PvLine] = [], bestMove: Move? = nil) {
        self.depth = depth
        self.nodes = nodes
        self.nps = nps
        self.lines = lines
        self.bestMove = bestMove
    }
}

/// 引擎 option 声明（来自 `option name ...` 行）。
public struct EngineOption: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case check(default: Bool)
        case spin(default: Int, min: Int, max: Int)
        case combo(default: String, vars: [String])
        case button
        case string(default: String)
    }

    public var name: String
    public var kind: Kind

    public init(name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }
}

/// 对弈搜索的时限控制。
public enum TimeControl: Equatable, Sendable {
    case movetime(Int)  // 毫秒
    case depth(Int)
}

/// 引擎会话错误。
public enum EngineError: Error, Equatable, LocalizedError {
    case spawnFailed(String)
    case notStarted
    case disconnected
    case timeout(String)
    case noMove

    public var errorDescription: String? {
        switch self {
        case .spawnFailed(let s): return "引擎启动失败：\(s)"
        case .notStarted: return "引擎会话未启动"
        case .disconnected: return "引擎已断开"
        case .timeout(let s): return "引擎超时（\(s)）"
        case .noMove: return "引擎未返回着法"
        }
    }
}
