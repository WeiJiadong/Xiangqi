import Foundation

/// UCI 引擎会话：单进程、专用读线程、actor 单消费、单 go 在飞的不变量。
public actor UCISession {

    private enum EventKind: Equatable {
        case uciok, readyok, bestmove
    }

    private struct Pending {
        let kind: EventKind
        let token: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }
    private var nextToken: UInt64 = 1

    // MARK: - state

    public private(set) var engineName: String?
    public private(set) var engineAuthor: String?
    public private(set) var options: [EngineOption] = []
    public private(set) var snapshot = AnalysisSnapshot()
    public private(set) var isRunning = false

    private var process: Process?
    private var stdin: FileHandle?
    private var pending: Pending?
    private var disconnected = false
    private var consumerTask: Task<Void, Never>?
    private var rawLog: [String] = []
    private let rawLogCap = 400
    /// start() 时配置的 Threads 值；searchLines 结束后复位用。
    private var initialThreads = 1

    public init() {}

    // MARK: - start / shutdown

    /// 启动引擎：spawn（cwd 设为引擎目录）→ uci → 等 uciok → setoptions → isready → 等 readyok。
    /// EvalFile 用绝对路径作为双保险（cwd 已是引擎目录）。
    public func start(enginePath: String, options: [(name: String, value: String)] = []) async throws {
        guard FileManager.default.isExecutableFile(atPath: enginePath) else {
            throw EngineError.spawnFailed("engine not executable: \(enginePath)")
        }
        let dir = (enginePath as NSString).deletingLastPathComponent
        let nnue = dir + "/pikafish.nnue"
        let hasNNUE = FileManager.default.fileExists(atPath: nnue)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: enginePath)
        proc.currentDirectoryURL = URL(fileURLWithPath: dir)
        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = Pipe()  // 丢弃 stderr

        do {
            try proc.run()
        } catch {
            throw EngineError.spawnFailed("spawn failed: \(error.localizedDescription)")
        }
        process = proc
        stdin = inPipe.fileHandleForWriting
        isRunning = true

        // 读线程：专用 Thread 阻塞读，事件经 AsyncStream 交给 actor 单消费。
        let (stream, cont) = AsyncStream.makeStream(of: String.self)
        let reader = LineReader(handle: outPipe.fileHandleForReading) { line in
            cont.yield(line)
        } onEOF: {
            cont.finish()
        }
        Thread { reader.run() }.start()

        consumerTask = Task { [weak self] in
            await self?.consume(stream: stream)
        }

        // 握手：uci → uciok → setoptions → isready → readyok
        send("uci")
        try await awaitEvent(.uciok, timeout: 5.0)

        if hasNNUE { send("setoption name EvalFile value \(nnue)") }
        for opt in options {
            send("setoption name \(opt.name) value \(opt.value)")
            if opt.name == "Threads", let t = Int(opt.value) { initialThreads = t }
        }
        send("isready")
        try await awaitEvent(.readyok, timeout: 5.0)
    }

    public func shutdown() async {
        guard isRunning else { return }
        send("quit")
        try? await Task.sleep(nanoseconds: 300_000_000)
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        stdin = nil
        isRunning = false
    }

    // MARK: - 对弈搜索

    /// 单次 go：返回 bestmove。调用方须保证 idle；返回后回 idle。
    public func searchGame(fen: String, moves: [Move], tc: TimeControl) async throws -> Move {
        try ensureReady()
        snapshot = AnalysisSnapshot()
        send("setoption name MultiPV value 1")
        send(positionCmd(fen: fen, moves: moves))
        let timeout: TimeInterval
        switch tc {
        case .movetime(let ms):
            timeout = Double(ms) / 1000.0 + 5.0
            send("go movetime \(ms)")
        case .depth(let d):
            timeout = 60.0
            send("go depth \(d)")
        }
        try await awaitEvent(.bestmove, timeout: timeout)
        guard let bm = snapshot.bestMove else { throw EngineError.noMove }
        return bm
    }

    /// 多行搜索（支招讲解用，确定性）：单线程 + 清空置换表 + 固定深度，
    /// 同一局面、同一引擎参数下每次必得同一评分序列（消除多线程调度与时间裁剪的随机性）。
    /// 调用方须保证 idle；返回时把 Threads / MultiPV 复位为会话初始值，以免拖慢后续 searchGame。
    public func searchLines(fen: String, moves: [Move], depth: Int, multiPV: Int) async throws -> [PvLine] {
        try ensureReady()
        snapshot = AnalysisSnapshot()
        send("setoption name Threads value 1")
        send("setoption name MultiPV value \(max(1, multiPV))")
        send("ucinewgame")        // 清 TT：消除前次搜索残留对结果的影响
        send("isready")
        try await awaitEvent(.readyok, timeout: 10.0)
        send(positionCmd(fen: fen, moves: moves))
        send("go depth \(depth)")
        try await awaitEvent(.bestmove, timeout: 120.0)
        send("setoption name MultiPV value 1")
        send("setoption name Threads value \(initialThreads)")  // 复位供 searchGame 复用
        let lines = snapshot.lines.filter { !$0.moves.isEmpty }
        return lines.sorted { Self.scoreRank($0.score) > Self.scoreRank($1.score) }
    }

    /// 评分排序键（行棋方视角）：己方杀步数越小越优且优于一切 cp；被杀局垫底，步数越大越优。
    private static func scoreRank(_ score: Score?) -> Double {
        guard let score else { return -.infinity }
        switch score {
        case .cp(let v): return Double(v)
        case .mate(let n): return n > 0 ? 100_000 - Double(n) : -100_000 - Double(n)
        }
    }

    // MARK: - 无限分析

    /// 启动 go infinite（无续延；通过快照轮询取 info）。调用方须保证 idle。
    public func startAnalysis(fen: String, moves: [Move], multiPV: Int) async throws {
        try ensureReady()
        snapshot = AnalysisSnapshot()
        send("setoption name MultiPV value \(multiPV)")
        send(positionCmd(fen: fen, moves: moves))
        send("go infinite")
    }

    /// 停止分析：发 stop 并等 bestmove 到达，确保"至多一个 go 在飞"不变量。
    public func stopAnalysis() async throws {
        try await stopSearch()
    }

    /// 停止当前 go（对弈搜索或分析）并等 bestmove，维持"至多一个 go 在飞"不变量。
    public func stopSearch() async throws {
        try ensureReady()
        send("stop")
        try await awaitEvent(.bestmove, timeout: 10.0)
    }

    /// 打断在飞 go：只发 stop 不等待，由既有 waiter（如 searchGame 调用方）收尾。
    /// 用于对弈搜索中让位给新搜索——先 interrupt 再等旧任务结束，避免并发 waiter。
    public func interrupt() {
        guard isRunning else { return }
        send("stop")
    }

    // MARK: - internals

    private func ensureReady() throws {
        if disconnected { throw EngineError.disconnected }
        guard isRunning else { throw EngineError.notStarted }
    }

    private func send(_ cmd: String) {
        log("» \(cmd)")
        let data = (cmd + "\n").data(using: .utf8) ?? Data()
        stdin?.write(data)
    }

    private func log(_ s: String) {
        rawLog.append(s)
        if rawLog.count > rawLogCap { rawLog.removeFirst(rawLog.count - rawLogCap) }
    }

    public func recentRawLog() -> [String] { rawLog }

    private func positionCmd(fen: String, moves: [Move]) -> String {
        if moves.isEmpty && fen == Fen.startpos {
            return "position startpos"
        }
        let movesStr = moves.map { $0.uci }.joined(separator: " ")
        return movesStr.isEmpty ? "position fen \(fen)" : "position fen \(fen) moves \(movesStr)"
    }

    // MARK: - 事件等待

    private func awaitEvent(_ kind: EventKind, timeout: TimeInterval) async throws {
        precondition(pending == nil, "UCISession: concurrent event waiters not supported")
        let token = nextToken
        nextToken &+= 1
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pending = Pending(kind: kind, token: token, continuation: cont)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self?.timeoutFired(token)
            }
        }
    }

    private func timeoutFired(_ token: UInt64) {
        guard let pd = pending, pd.token == token else { return }
        pending = nil
        pd.continuation.resume(throwing: EngineError.timeout(String(describing: pd.kind)))
    }

    private func resolvePending(_ kind: EventKind) {
        guard let pd = pending, pd.kind == kind else { return }
        pending = nil
        pd.continuation.resume()
    }

    // MARK: - 消费循环

    private func consume(stream: AsyncStream<String>) async {
        for await line in stream {
            handleLine(line)
        }
        // EOF：唤醒所有挂起者并标记断连
        disconnected = true
        isRunning = false
        if let pd = pending {
            pending = nil
            pd.continuation.resume(throwing: EngineError.disconnected)
        }
    }

    private func handleLine(_ line: String) {
        log("« \(line)")
        guard let event = UCIParser.parseLine(line) else { return }
        switch event {
        case .idName(let n): engineName = n
        case .idAuthor(let a): engineAuthor = a
        case .uciok: resolvePending(.uciok)
        case .readyok: resolvePending(.readyok)
        case .option(let o): options.append(o)
        case .info(let l): applyInfo(l)
        case .bestmove(let mv, _):
            snapshot.bestMove = mv
            resolvePending(.bestmove)
        }
    }

    // MARK: - info 快照

    private func applyInfo(_ l: InfoLine) {
        if let d = l.depth { snapshot.depth = d }
        if let n = l.nodes { snapshot.nodes = n }
        if let n = l.nps { snapshot.nps = n }

        let idx = (l.multipv ?? 1) - 1
        guard idx >= 0 else { return }
        while snapshot.lines.count <= idx {
            snapshot.lines.append(PvLine(multipv: snapshot.lines.count + 1))
        }
        var line = snapshot.lines[idx]
        line.multipv = l.multipv ?? 1
        if let d = l.depth { line.depth = d }
        if let s = l.score { line.score = s }
        if !l.pv.isEmpty { line.moves = l.pv }
        snapshot.lines[idx] = line
    }
}

// MARK: - LineReader (读线程)

/// 阻塞式逐行读：由专用 Thread 驱动，避免占用协作线程池。
private final class LineReader: @unchecked Sendable {
    private let handle: FileHandle
    private let onLine: (String) -> Void
    private let onEOF: () -> Void
    private var bytes: [UInt8] = []

    init(handle: FileHandle, onLine: @escaping (String) -> Void, onEOF: @escaping () -> Void) {
        self.handle = handle
        self.onLine = onLine
        self.onEOF = onEOF
    }

    func run() {
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {  // EOF
                flushTail()
                onEOF()
                return
            }
            bytes.append(contentsOf: chunk)
            while let nl = bytes.firstIndex(of: 0x0A) {
                var line = Array(bytes[0..<nl])
                bytes.removeSubrange(0...nl)
                if line.last == 0x0D { line.removeLast() }
                if let s = String(bytes: line, encoding: .utf8) {
                    onLine(s)
                }
            }
        }
    }

    private func flushTail() {
        guard !bytes.isEmpty else { return }
        if let s = String(bytes: bytes, encoding: .utf8) {
            onLine(s)
        }
        bytes.removeAll()
    }
}
