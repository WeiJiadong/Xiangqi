import SwiftUI
import XiangqiCore

/// 屏幕坐标 <-> 棋盘交点 唯一换算实现（含 Y 翻转 / 执黑翻转）。
/// 象棋棋子落在横竖线交叉点上，而非格子内。
struct BoardGeometry {
    let size: CGSize
    let flipped: Bool

    /// 网格外四周各留 0.55 格边距（边线上的棋子与外框不裁切）。
    /// 9 条竖线占 8 个格距、10 条横线占 9 个格距。
    var cell: CGFloat { min(size.width / 9.1, size.height / 10.1) }
    var gridSize: CGSize { CGSize(width: cell * 8, height: cell * 9) }

    /// 左上角交点（file 0 / 最上横线的交叉处）。
    var gridOrigin: CGPoint {
        CGPoint(x: (size.width - gridSize.width) / 2,
                y: (size.height - gridSize.height) / 2)
    }

    /// 网格总包络（供 Canvas 画线使用）。
    var frame: CGRect {
        let o = gridOrigin
        return CGRect(x: o.x, y: o.y, width: gridSize.width, height: gridSize.height)
    }

    /// 交点中心（红方视角 rank0 在下；flipped 时上下翻转）。
    func point(for square: Square) -> CGPoint {
        let file = square % 9
        let rank = square / 9
        let row = flipped ? rank : 9 - rank
        let o = gridOrigin
        return CGPoint(x: o.x + cell * CGFloat(file),
                       y: o.y + cell * CGFloat(row))
    }

    /// 命中最邻近交点；超出容差返回 nil。
    func square(at p: CGPoint) -> Square? {
        let o = gridOrigin
        let fx = (p.x - o.x) / cell
        let fy = (p.y - o.y) / cell
        guard fx >= -0.45, fx <= 8.45, fy >= -0.45, fy <= 9.45 else { return nil }
        let file = Int(fx.rounded())
        let row = Int(fy.rounded())
        guard (0...8).contains(file), (0...9).contains(row) else { return nil }
        let rank = flipped ? row : 9 - row
        return Square(file: file, rank: rank)
    }

    /// 棋子直径。
    var pieceDiameter: CGFloat { cell * 0.92 }
}
