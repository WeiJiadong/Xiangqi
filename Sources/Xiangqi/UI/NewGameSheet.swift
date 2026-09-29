import SwiftUI
import XiangqiCore

/// 新对局面板：唯一模式为分析学习（人执红、引擎执黑），仅调引擎参数。
struct NewGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: GameConfig
    let onStart: (GameConfig) -> Void

    @State private var threads: Int
    @State private var hashMB: Int

    init(current: GameConfig, onStart: @escaping (GameConfig) -> Void) {
        self.current = current
        self.onStart = onStart
        _threads = State(initialValue: current.threads)
        _hashMB = State(initialValue: current.hashMB)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新对局").font(.title2.bold())
            Divider()
            Text("模式：分析学习（双方均手动走子，引擎仅支招）")
                .font(.callout)
                .foregroundColor(.secondary)
            HStack {
                Stepper("线程 \(threads)", value: $threads, in: 1...16)
                    .frame(width: 180, alignment: .leading)
                Spacer()
                Stepper("哈希 \(hashMB)MB", value: $hashMB, in: 16...1024, step: 16)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button("开始") {
                    onStart(GameConfig(timeControl: current.timeControl,
                                       threads: threads, hashMB: hashMB))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
