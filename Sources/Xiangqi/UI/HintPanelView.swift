import SwiftUI
import XiangqiCore

/// 支招行样式：按名次取色（最佳绿、次选蓝、第三灰、其余橙），棋盘箭头与讲解面板共用。
enum HintStyle {
    static func color(_ rank: Int) -> SwiftUI.Color {
        switch rank {
        case 0: return .green
        case 1: return SwiftUI.Color(red: 0.12, green: 0.47, blue: 0.87)
        case 2: return .gray
        default: return SwiftUI.Color(red: 0.95, green: 0.55, blue: 0.10)
        }
    }
}

/// 支招讲解面板：总评分 + 备选着法列表，点击行高亮棋盘对应箭头。
/// 评分统一为支招方（行棋方）视角：正 = 支招方优；列表按优劣降序，数字自上而下递减。
struct HintPanelView: View {
    let lines: [PvLine]
    let side: XiangqiCore.Color
    let board: Board
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("支招讲解").font(.headline)
            if let first = lines.first, let score = first.score {
                Text(headerText(score))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    if let mv = line.moves.first {
                        Button {
                            onSelect(idx)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(HintStyle.color(idx))
                                    .frame(width: 8, height: 8)
                                Text("\(idx + 1).")
                                    .font(.callout.monospacedDigit())
                                    .frame(width: 22, alignment: .leading)
                                Text(ChineseNotation.notation(board, mv))
                                    .font(.callout)
                                Spacer()
                                Text(rowScoreText(line.score))
                                    .font(.callout.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(selectedIndex == idx
                                          ? SwiftUI.Color.accentColor.opacity(0.18)
                                          : SwiftUI.Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let depth = lines.compactMap(\.depth).max() {
                Text("引擎深度 \(depth) · 评分为支招方视角（正 = 支招方优）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 评分文案

    /// 支招方名称（评分与文案均以支招方为主语）。
    private var sideName: String { side == .red ? "红" : "黑" }

    /// 头部总评分：杀局展示步数，其余按分差分档（支招方视角，正 = 支招方优）。
    private func headerText(_ score: Score) -> String {
        if case .mate(let n) = score {
            return n > 0 ? "\(sideName)方 \(n) 步杀" : "\(sideName)方 \(-n) 步内被杀"
        }
        guard case .cp(let v) = score else { return "局面未知" }
        let value = String(format: "%+.2f", Double(v) / 100)
        switch abs(v) {
        case ..<30: return "均势 \(value)"
        case ..<100: return v > 0 ? "\(sideName)方略优 \(value)" : "\(sideName)方略劣 \(value)"
        case ..<300: return v > 0 ? "\(sideName)方优势 \(value)" : "\(sideName)方劣势 \(value)"
        default: return v > 0 ? "\(sideName)方大优 \(value)" : "\(sideName)方大劣 \(value)"
        }
    }

    /// 行评分：支招方视角带符号分值（自上而下递减）；杀局显示"杀N / 被杀N"。
    private func rowScoreText(_ score: Score?) -> String {
        guard let score else { return "—" }
        if case .mate(let n) = score {
            return n > 0 ? "杀\(n)" : "被杀\(-n)"
        }
        guard case .cp(let v) = score else { return "—" }
        return String(format: "%+.2f", Double(v) / 100)
    }
}
