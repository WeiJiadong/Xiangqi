import Foundation
import Observation
import SwiftUI
import XiangqiCore

struct PieceSlot: Identifiable, Equatable {
    let id: UUID
    var piece: Piece
    var square: Square
}

enum GameResult: Equatable {
    case win(winner: XiangqiCore.Color, by: String)
    case draw
}

/// 学习模式：双人对弈（人手动走双方），引擎仅在"支招"时介入。
/// 引擎从不自行落子。
@MainActor
@Observable
final class GameStore {
    private(set) var board: Board = .standard()
    private(set) var slots: [PieceSlot] = []
    private(set) var history: [Move] = []
    private(set) var redoStack: [Move] = []
    private(set) var notations: [String] = []
    private(set) var selected: Square?
    private(set) var selectedTargets: [Square] = []
    private(set) var lastMove: Move?
    private(set) var result: GameResult?
    private(set) var config = GameConfig.standard
    private(set) var engineError: String?
    private(set) var boardFlipped = false
    private(set) var hintMove: Move?
    private(set) var hintText: String?
    private(set) var hintLoading = false
    private(set) var editMode = false
    var editBrush: Piece = .redKing
    private(set) var editError: String?

    /// 编辑调色盘：红七子 + 黑七子（空白画笔由 UI 单独提供）。
    static let editPalette: [Piece] = [
        .redKing, .redAdvisor, .redElephant, .redHorse, .redRook, .redCannon, .redPawn,
        .blackKing, .blackAdvisor, .blackElephant, .blackHorse, .blackRook, .blackCannon, .blackPawn,
    ]

    private var session: UCISession?
    private var baseFen = Fen.startpos
    private var engineTaskID = UUID()
    private var hintTask: Task<Void, Never>?
    private var editBackup: Board?

    var statusText: String {
        if editMode { return "棋盘编辑中：点击棋盘放置选中棋子" }
        if let result {
            switch result {
            case .win(let winner, let by): return "\(winner == .red ? "红" : "黑")方胜（\(by)）"
            case .draw: return "和棋" }
        }
        if hintLoading { return "支招计算中…" }
        if Rules.inCheck(board, board.sideToMove) { return "\(board.sideToMove == .red ? "红" : "黑")方被将军" }
        return "轮到\(board.sideToMove == .red ? "红" : "黑")方"
    }

    init() { rebuildSlots() }

    /// 开始新对局：重置局面；引擎会话留待首次支招时惰性建立。
    func startGame(_ cfg: GameConfig) async {
        config = cfg
        engineTaskID = UUID()
        engineError = nil
        hintLoading = false
        clearHint()
        // 旧会话随配置失效，重启时让 Threads/Hash 重新生效
        if session != nil {
            await session?.shutdown()
            session = nil
        }
        resetBoard()
    }

    /// 反转棋盘视角。
    func toggleBoardFlip() {
        boardFlipped.toggle()
    }

    /// 手动指定当前行棋方：以当前局面为新起点（着法记录清零）。
    func setSideToMove(_ color: XiangqiCore.Color) {
        guard result == nil, !hintLoading, !editMode else { return }
        board.sideToMove = color
        baseFen = Fen.serialize(board)
        history.removeAll()
        redoStack.removeAll()
        notations.removeAll()
        selected = nil
        selectedTargets.removeAll()
        lastMove = nil
        result = nil
        engineError = nil
        clearHint()
        refreshCheck()
        evaluateResult()
    }

    // MARK: - 棋盘编辑

    /// 进入编辑模式：作废在飞支招、保留当前布局。
    func enterEditMode() async {
        guard !editMode else { return }
        engineTaskID = UUID()          // 使在飞支招结果失效
        await session?.interrupt()
        await hintTask?.value
        hintLoading = false
        selected = nil
        selectedTargets.removeAll()
        clearHint()
        editError = nil
        editBrush = .redKing
        editBackup = board
        editMode = true
    }

    /// 完成编辑：校验双方各恰好一王；通过则以当前局面为新起点。
    func finishEditMode() {
        guard editMode else { return }
        let redKings = (0..<90).filter { board[$0] == .redKing }.count
        let blackKings = (0..<90).filter { board[$0] == .blackKing }.count
        guard redKings == 1, blackKings == 1 else {
            editError = "双方必须各有且只有一个帅/将（当前红 \(redKings) 个、黑 \(blackKings) 个）"
            return
        }
        editMode = false
        editError = nil
        editBackup = nil
        baseFen = Fen.serialize(board)
        history.removeAll()
        redoStack.removeAll()
        notations.removeAll()
        selected = nil
        selectedTargets.removeAll()
        lastMove = nil
        result = nil
        engineError = nil
        clearHint()
        refreshCheck()
        evaluateResult()
    }

    /// 取消编辑：恢复进入前的局面。
    func cancelEditMode() {
        guard editMode else { return }
        editMode = false
        editError = nil
        if let b = editBackup {
            board = b
            baseFen = Fen.serialize(b)
        }
        editBackup = nil
        rebuildSlots()
        refreshCheck()
    }

    /// 清空棋盘（保留行棋方）。
    func clearEditBoard() {
        guard editMode else { return }
        board = Board(sideToMove: board.sideToMove)
        rebuildSlots()
        editError = nil
    }

    /// 支招：给当前轮到方算最佳着法（限时 1.5 秒），棋盘高亮 + 文字提示。
    /// 引擎只算不动手——仅显示建议，不落子。
    func requestHint() {
        guard result == nil, !hintLoading, !editMode else { return }
        engineTaskID = UUID()
        let id = engineTaskID
        hintLoading = true
        let fen = baseFen, moves = history
        hintTask = Task {
            defer { if id == self.engineTaskID { self.hintLoading = false } }
            do {
                if self.session == nil {
                    guard await self.ensureEngineSession() else { return }
                }
                guard let s = self.session else { return }
                let bm = try await self.hintSearch(s: s, fen: fen, moves: moves)
                guard id == self.engineTaskID else { return }
                guard Rules.legalMoves(self.board).contains(bm) else {
                    self.engineError = "引擎返回非法着法：\(bm.uci)"
                    return
                }
                self.applyHint(bm)
            } catch {
                guard id == self.engineTaskID else { return }
                self.engineError = "支招失败：\(error.localizedDescription)"
            }
        }
    }

    private func applyHint(_ mv: Move) {
        hintMove = mv
        hintText = ChineseNotation.notation(board, mv)
    }

    /// 支招搜索：notStarted/disconnected 时透明重建会话并重试一次。
    private func hintSearch(s: UCISession, fen: String, moves: [Move]) async throws -> Move {
        do {
            return try await s.searchGame(fen: fen, moves: moves, tc: .movetime(1500))
        } catch EngineError.notStarted, EngineError.disconnected {
            guard await ensureEngineSession(), let s2 = session else { throw EngineError.notStarted }
            return try await s2.searchGame(fen: fen, moves: moves, tc: .movetime(1500))
        }
    }

    private func clearHint() {
        hintMove = nil
        hintText = nil
    }

    /// 后退：回退最后一着，进入 redo 缓冲，可前进恢复。
    func goBack() {
        guard !history.isEmpty, !hintLoading, !editMode else { return }
        redoStack.append(history.removeLast())
        replayFromStart()
        result = nil
        engineError = nil
        clearHint()
    }

    /// 前进：恢复最近一次后退掉的着法。
    func goForward() {
        guard !redoStack.isEmpty, !hintLoading, !editMode else { return }
        history.append(redoStack.removeLast())
        replayFromStart()
        result = nil
        engineError = nil
        clearHint()
    }

    /// 点击交叉点：编辑态放置画笔棋子；否则选中己方棋子 / 走子 / 重选 / 取消。
    func tap(square: Square) {
        if editMode {
            board[square] = editBrush
            rebuildSlots()
            editError = nil
            return
        }
        if result != nil || hintLoading { return }
        clearHint()
        if let sel = selected {
            if selectedTargets.contains(square) {
                play(Move(from: sel, to: square))
                return
            }
        }
        let p = board[square]
        if p != .empty && p.color == board.sideToMove {
            selected = square
            selectedTargets = Rules.legalMoves(board)
                .filter { $0.from == square }
                .map { $0.to }
                .sorted { ($0 % 9, $0 / 9) < ($1 % 9, $1 / 9) }
        } else {
            selected = nil
            selectedTargets.removeAll()
        }
    }

    // MARK: - internals

    private func resetBoard() {
        board = .standard()
        baseFen = Fen.startpos
        history.removeAll()
        redoStack.removeAll()
        notations.removeAll()
        selected = nil
        selectedTargets.removeAll()
        lastMove = nil
        result = nil
        clearHint()
        rebuildSlots()
    }

    /// 启动全新引擎会话（首次支招或重建时调用，确保 Threads/Hash 生效）。
    private func ensureEngineSession() async -> Bool {
        if let old = session { await old.shutdown() }
        let s = UCISession()
        do {
            try await s.start(enginePath: AppSettings.enginePath, options: [
                (name: "Threads", value: "\(config.threads)"),
                (name: "Hash", value: "\(config.hashMB)"),
            ])
            session = s
            return true
        } catch {
            session = nil
            engineError = "引擎启动失败：\(error.localizedDescription)"
            return false
        }
    }

    private func play(_ move: Move) {
        guard Rules.legalMoves(board).contains(move) else { return }
        var slots = slots
        slots.removeAll { $0.square == move.to }  // 先吃子，避免索引位移
        if let idx = slots.firstIndex(where: { $0.square == move.from }) {
            slots[idx].square = move.to
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            self.slots = slots
        }
        let notation = ChineseNotation.notation(board, move)
        board = board.apply(move)
        history.append(move)
        redoStack.removeAll()  // 分叉：旧分支的未来不可恢复
        notations.append(notation)
        selected = nil
        selectedTargets.removeAll()
        clearHint()
        lastMove = move
        refreshCheck()
        evaluateResult()
    }

    private func replayFromStart() {
        var b = Fen.parse(baseFen) ?? .standard()
        var notes: [String] = []
        for mv in history {
            notes.append(ChineseNotation.notation(b, mv))
            b = b.apply(mv)
        }
        board = b
        notations = notes
        selected = nil
        selectedTargets.removeAll()
        lastMove = history.last
        rebuildSlots()
        refreshCheck()
    }

    private func rebuildSlots() {
        slots = (0..<90).compactMap { sq -> PieceSlot? in
            let p = board[sq]
            guard p != .empty else { return nil }
            return PieceSlot(id: UUID(), piece: p, square: sq)
        }
    }

    private func refreshCheck() {
        if Rules.inCheck(board, board.sideToMove) {
            checkedKingSquare = board.kingSquare(board.sideToMove)
        } else {
            checkedKingSquare = nil
        }
    }

    private var checkedKingSquare: Square?

    var checkSquare: Square? { checkedKingSquare }

    private func evaluateResult() {
        let loser = board.sideToMove
        if Rules.legalMoves(board).isEmpty {
            result = Rules.inCheck(board, loser)
                ? .win(winner: loser.flipped, by: "绝杀")
                : .win(winner: loser.flipped, by: "困毙")
        }
    }
}
