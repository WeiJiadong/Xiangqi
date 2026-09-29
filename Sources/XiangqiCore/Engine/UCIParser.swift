import Foundation

/// UCI 行解析事件（一条引擎输出行的语义映射）。
public enum UCIEvent: Equatable, Sendable {
    case idName(String)
    case idAuthor(String)
    case uciok
    case readyok
    case option(EngineOption)
    case info(InfoLine)
    case bestmove(Move?, ponder: Move?)
}

/// info 行的解析结果。
public struct InfoLine: Equatable, Sendable {
    public var depth: Int?
    public var seldepth: Int?
    public var multipv: Int?
    public var score: Score?
    public var nodes: Int64?
    public var nps: Int64?
    public var timeMs: Int64?
    public var pv: [Move]
    public var lowerbound: Bool
    public var upperbound: Bool

    public init(depth: Int? = nil, seldepth: Int? = nil, multipv: Int? = nil,
                score: Score? = nil, nodes: Int64? = nil, nps: Int64? = nil,
                timeMs: Int64? = nil, pv: [Move] = [], lowerbound: Bool = false,
                upperbound: Bool = false) {
        self.depth = depth
        self.seldepth = seldepth
        self.multipv = multipv
        self.score = score
        self.nodes = nodes
        self.nps = nps
        self.timeMs = timeMs
        self.pv = pv
        self.lowerbound = lowerbound
        self.upperbound = upperbound
    }
}

/// 纯函数解析器：无副作用，输入一行 UCI 输出，输出 UCIEvent?（无法识别返回 nil）。
public enum UCIParser {

    public static func parseLine(_ raw: String) -> UCIEvent? {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }
        let tokens = line.split(separator: " ").map(String.init)
        guard let head = tokens.first else { return nil }
        switch head {
        case "id":
            return parseId(tokens)
        case "uciok":
            return .uciok
        case "readyok":
            return .readyok
        case "option":
            return parseOption(tokens)
        case "info":
            return parseInfo(tokens)
        case "bestmove":
            return parseBestmove(tokens)
        default:
            return nil
        }
    }

    // MARK: - id

    private static func parseId(_ tokens: [String]) -> UCIEvent? {
        guard tokens.count >= 3, tokens[1] == "name" || tokens[1] == "author" else { return nil }
        let rest = tokens[2..<tokens.count].joined(separator: " ")
        return tokens[1] == "name" ? .idName(rest) : .idAuthor(rest)
    }

    // MARK: - option

    private static func parseOption(_ tokens: [String]) -> UCIEvent? {
        // 形如：option name Hash type spin default 16 min 1 max 1024
        var i = 1
        var name = ""
        var type = ""
        var def = ""
        var mn: Int?
        var mx: Int?
        var vars: [String] = []

        while i < tokens.count {
            switch tokens[i] {
            case "name":
                i += 1
                var parts: [String] = []
                while i < tokens.count, !["type", "default", "min", "max", "var"].contains(tokens[i]) {
                    parts.append(tokens[i]); i += 1
                }
                name = parts.joined(separator: " ")
            case "type":
                i += 1
                if i < tokens.count { type = tokens[i]; i += 1 }
            case "default":
                i += 1
                if i < tokens.count { def = tokens[i]; i += 1 }
            case "min":
                i += 1
                if i < tokens.count { mn = Int(tokens[i]) }; if i < tokens.count { i += 1 }
            case "max":
                i += 1
                if i < tokens.count { mx = Int(tokens[i]) }; if i < tokens.count { i += 1 }
            case "var":
                i += 1
                if i < tokens.count { vars.append(tokens[i]); i += 1 }
            default:
                i += 1
            }
        }

        guard !name.isEmpty, !type.isEmpty else { return nil }
        let kind: EngineOption.Kind
        switch type {
        case "check":
            kind = .check(default: def == "true")
        case "spin":
            kind = .spin(default: Int(def) ?? 0, min: mn ?? 0, max: mx ?? 0)
        case "combo":
            kind = .combo(default: def, vars: vars)
        case "button":
            kind = .button
        case "string":
            kind = .string(default: def)
        default:
            return nil
        }
        return .option(EngineOption(name: name, kind: kind))
    }

    // MARK: - info

    private static func parseInfo(_ tokens: [String]) -> UCIEvent? {
        var l = InfoLine()
        var i = 1
        while i < tokens.count {
            let key = tokens[i]
            switch key {
            case "depth":     i += 1; if i < tokens.count { l.depth = Int(tokens[i]); i += 1 }
            case "seldepth":  i += 1; if i < tokens.count { l.seldepth = Int(tokens[i]); i += 1 }
            case "multipv":   i += 1; if i < tokens.count { l.multipv = Int(tokens[i]); i += 1 }
            case "nodes":     i += 1; if i < tokens.count { l.nodes = Int64(tokens[i]) }; if i < tokens.count { i += 1 }
            case "nps":       i += 1; if i < tokens.count { l.nps = Int64(tokens[i]) }; if i < tokens.count { i += 1 }
            case "time":      i += 1; if i < tokens.count { l.timeMs = Int64(tokens[i]) }; if i < tokens.count { i += 1 }
            case "hashfull", "tbhits": i += 1; if i < tokens.count { i += 1 }
            case "score":
                i += 1
                guard i < tokens.count else { break }
                let kind = tokens[i]
                i += 1
                guard i < tokens.count, let v = Int(tokens[i]) else { break }
                i += 1
                l.score = kind == "mate" ? .mate(v) : .cp(v)
            case "lowerbound": l.lowerbound = true; i += 1
            case "upperbound": l.upperbound = true; i += 1
            case "pv":
                i += 1
                while i < tokens.count {
                    let mv = tokens[i]
                    if mv == "string" { break }
                    if let m = Move.parse(mv) { l.pv.append(m) } else { break }
                    i += 1
                }
            default:
                i += 1
            }
        }
        return .info(l)
    }

    // MARK: - bestmove

    private static func parseBestmove(_ tokens: [String]) -> UCIEvent? {
        guard tokens.count >= 2 else { return .bestmove(nil, ponder: nil) }
        let mv = tokens[1] == "(none)" ? nil : Move.parse(tokens[1])
        var ponder: Move?
        if tokens.count >= 4, tokens[2] == "ponder" {
            ponder = Move.parse(tokens[3])
        }
        return .bestmove(mv, ponder: ponder)
    }
}
