import SwiftUI
import XiangqiCore

struct ContentView: View {
    @State private var store = GameStore()
    @State private var showNewGame = false

    var body: some View {
        HStack(spacing: 0) {
            BoardView(store: store, flipped: store.boardFlipped)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
            Divider()
            rightPanel
                .frame(width: 300)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 920, minHeight: 680)
        .sheet(isPresented: $showNewGame) {
            NewGameSheet(current: store.config) { cfg in
                Task { await store.startGame(cfg) }
            }
        }
        .alert("对局结束",
               isPresented: Binding(get: { store.result != nil }, set: { _, _ in })) {
            Button("新对局") { showNewGame = true }
            Button("关闭", role: .cancel) {}
        } message: {
            if let r = store.result {
                switch r {
                case .win(let w, let by): Text("\(w == .red ? "红" : "黑")方胜（\(by)）")
                case .draw: Text("和棋")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("新对局") { showNewGame = true }
                    .keyboardShortcut("n")
                Button("后退") { store.goBack() }
                    .disabled(store.history.isEmpty || store.hintLoading || store.editMode
                              || store.anyAutoPlay)
                    .keyboardShortcut("z")
                Button("前进") { store.goForward() }
                    .disabled(store.redoStack.isEmpty || store.hintLoading || store.editMode
                              || store.anyAutoPlay)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                Button {
                    store.requestHint()
                } label: {
                    if store.hintLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("支招")
                    }
                }
                .disabled(store.result != nil || store.hintLoading || store.editMode
                          || store.autoSides.contains(store.board.sideToMove))
                .help("引擎算当前轮到方的最佳着法（限时 1.5 秒）")
                Button {
                    store.toggleAutoPlay(.red)
                } label: {
                    Text(store.autoPlayRed ? "停止帮红" : "帮红走棋")
                }
                .disabled(store.editMode || store.result != nil)
                .help("引擎自动替红方走子，再点一次停止")
                Button {
                    store.toggleAutoPlay(.black)
                } label: {
                    Text(store.autoPlayBlack ? "停止帮黑" : "帮黑走棋")
                }
                .disabled(store.editMode || store.result != nil)
                .help("引擎自动替黑方走子，再点一次停止")
                Button("反转棋盘") { store.toggleBoardFlip() }
                    .help("翻转棋盘视角")
                Button("编辑棋盘") { Task { await store.enterEditMode() } }
                    .disabled(store.editMode || store.result != nil)
                    .help("手动摆放棋子，研究任意局面")
                Menu {
                    Button("轮到红方") { store.setSideToMove(.red) }
                    Button("轮到黑方") { store.setSideToMove(.black) }
                } label: {
                    Text(store.board.sideToMove == .red ? "走方：红" : "走方：黑")
                }
                .disabled(store.result != nil || store.hintLoading || store.editMode
                          || store.anyAutoPlay)
                .help("手动指定当前行棋方（以当前局面为新起点，清空着法记录）")
                Spacer()
            }
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.statusText)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let err = store.engineError {
                Text(err)
                    .font(.callout)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let hint = store.hintText {
                Text("提示：\(hint)")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if store.editMode {
                editPanel
            } else {
                Divider()
                Text("着法记录")
                    .font(.headline)
                MoveListView(notations: store.notations)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("棋盘编辑").font(.headline)
            Text("选中棋子后点击棋盘放置；选「空」擦除。")
                .font(.caption)
                .foregroundColor(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)], spacing: 6) {
                ForEach(GameStore.editPalette, id: \.self) { p in
                    Button {
                        store.editBrush = p
                    } label: {
                        PieceView(piece: p, diameter: 32)
                            .overlay(
                                Circle().stroke(store.editBrush == p ? Color.accentColor : .clear,
                                                 lineWidth: 2.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    store.editBrush = .empty
                } label: {
                    Circle()
                        .stroke(Color.secondary.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 32, height: 32)
                        .overlay(Text("空").font(.caption2).foregroundColor(.secondary))
                        .overlay(
                            Circle().stroke(store.editBrush == .empty ? Color.accentColor : .clear,
                                            lineWidth: 2.5)
                        )
                }
                .buttonStyle(.plain)
            }
            Button("清空棋盘") { store.clearEditBoard() }
            if let e = store.editError {
                Text(e).font(.callout).foregroundColor(.red)
            }
            HStack {
                Button("取消") { store.cancelEditMode() }
                Spacer()
                Button("完成") { store.finishEditMode() }
                    .keyboardShortcut(.defaultAction)
            }
            Spacer()
        }
    }
}
