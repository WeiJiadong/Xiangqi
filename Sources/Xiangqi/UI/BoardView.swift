import SwiftUI
import XiangqiCore

private typealias SColor = SwiftUI.Color

/// 参考拟木风色板：黄木底 + 近黑线条 + 朱砂红。
private let inkLine = SColor(red: 0.12, green: 0.08, blue: 0.05)
private let vermilion = SColor(red: 0.776, green: 0.157, blue: 0.157)   // #C62828

struct BoardView: View {
    @Bindable var store: GameStore
    var flipped: Bool = false

    var body: some View {
        GeometryReader { geo in
            let g = BoardGeometry(size: geo.size, flipped: flipped)
            ZStack {
                Canvas { ctx, size in
                    drawBoard(&ctx, g: g)
                }
                markers(g)
                ForEach(store.slots) { slot in
                    PieceView(piece: slot.piece, diameter: g.pieceDiameter)
                        .position(g.point(for: slot.square))
                        .transition(.opacity)
                }
                // 支招箭头：仅画前 3 名（绿/蓝/灰）+ 用户点选的第 4、5 行（橙色），其余只在列表里
                if !store.hintLines.isEmpty {
                    Canvas { ctx, _ in
                        let sel = store.selectedHintLine ?? 0
                        for (idx, line) in store.hintLines.enumerated() {
                            guard idx < 3 || idx == sel else { continue }
                            guard let mv = line.moves.first else { continue }
                            let emphasized = sel == idx
                            let dim = store.selectedHintLine != nil && !emphasized
                            drawHintArrow(&ctx, g: g, move: mv,
                                          color: HintStyle.color(idx),
                                          width: g.pieceDiameter * (emphasized ? 0.18 : 0.11),
                                          alpha: dim ? 0.35 : 0.85)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                if let sq = g.square(at: value.location) {
                    store.tap(square: sq)
                }
            })
        }
        .aspectRatio(9.1 / 10.1, contentMode: .fit)
    }

    // MARK: - 标记层

    @ViewBuilder
    private func markers(_ g: BoardGeometry) -> some View {
        if let last = store.lastMove {
            // 起点虚环
            markerRing(g.point(for: last.from), diameter: g.pieceDiameter * 0.36,
                       stroke: SColor.accentColor.opacity(0.7), lineWidth: 1.5,
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            // 终点实环（略大，强调落点）
            markerRing(g.point(for: last.to), diameter: g.pieceDiameter * 0.48,
                       stroke: SColor.accentColor, lineWidth: 2.2,
                       style: StrokeStyle(lineWidth: 2.2))
            // 方向连线：起点→终点
            Path { p in
                p.move(to: g.point(for: last.from))
                p.addLine(to: g.point(for: last.to))
            }
            .stroke(SColor.accentColor.opacity(0.75),
                     style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
        }
        if let lineIdx = store.selectedHintLine ?? (store.hintLines.isEmpty ? nil : 0),
           store.hintLines.indices.contains(lineIdx),
           let hint = store.hintLines[lineIdx].moves.first {
            let style = StrokeStyle(lineWidth: 2, dash: [5, 3])
            let ringColor = HintStyle.color(lineIdx)
            markerRing(g.point(for: hint.from), diameter: g.pieceDiameter * 1.08,
                       stroke: ringColor, lineWidth: 2, style: style)
            markerRing(g.point(for: hint.to), diameter: g.pieceDiameter * 1.08,
                       stroke: ringColor, lineWidth: 2, style: style)
        }
        if let k = store.checkSquare {
            markerRing(g.point(for: k), diameter: g.pieceDiameter * 1.06, stroke: SColor.red, lineWidth: 2,
                       style: StrokeStyle(lineWidth: 2))
        }
        if let sel = store.selected {
            let p = g.point(for: sel)
            Circle()
                .fill(SColor.accentColor.opacity(0.18))
                .frame(width: g.pieceDiameter * 1.04, height: g.pieceDiameter * 1.04)
                .position(p)
            markerRing(p, diameter: g.pieceDiameter * 1.04, stroke: SColor.accentColor, lineWidth: 2,
                       style: StrokeStyle(lineWidth: 2))
        }
        ForEach(store.selectedTargets, id: \.self) { sq in
            let p = g.point(for: sq)
            if store.board[sq] != .empty {
                // 可吃：四角框
                CaptureCorners(diameter: g.pieceDiameter)
                    .position(p)
            } else {
                TargetDot(diameter: g.pieceDiameter * 0.3)
                    .position(p)
            }
        }
    }

    /// 确定性木纹：纵向细纹 + 弯曲纹路，固定种子避免重绘抖动。
    private func drawWoodGrain(_ ctx: inout GraphicsContext, in rect: CGRect) {
        var state: UInt64 = 0x9E3779B9_7F4A7C15
        func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
        // 纵向细纹条
        for _ in 0..<36 {
            let x = rect.minX + next() * rect.width
            let w = rect.width * (0.0015 + next() * 0.0035)
            let a = 0.025 + next() * 0.045
            ctx.fill(Path(CGRect(x: x, y: rect.minY, width: w, height: rect.height)),
                     with: .color(SColor(red: 0.42, green: 0.28, blue: 0.10).opacity(a)))
        }
        // 弯曲纹路
        for _ in 0..<14 {
            var x = rect.minX + next() * rect.width
            var grain = Path()
            grain.move(to: CGPoint(x: x, y: rect.minY))
            var y = rect.minY
            while y < rect.maxY {
                y += rect.height / 10
                x += (next() - 0.5) * rect.width * 0.008
                grain.addLine(to: CGPoint(x: x, y: min(y, rect.maxY)))
            }
            ctx.stroke(grain,
                       with: .color(SColor(red: 0.42, green: 0.28, blue: 0.10).opacity(0.05 + next() * 0.05)),
                       lineWidth: 0.8 + next() * 0.8)
        }
    }

    private func markerRing(_ p: CGPoint, diameter: CGFloat, stroke: SColor,
                            lineWidth: CGFloat, style: StrokeStyle = StrokeStyle(lineWidth: 1)) -> some View {
        Circle()
            .stroke(stroke, style: style)
            .frame(width: diameter, height: diameter)
            .position(p)
    }

    /// 支招箭头：粗杆圆帽 + 三角头，起终点稍收避开棋子圆心。
    private func drawHintArrow(_ ctx: inout GraphicsContext, g: BoardGeometry, move: Move,
                               color: SColor, width: CGFloat, alpha: CGFloat) {
        let from = g.point(for: move.from)
        let to = g.point(for: move.to)
        let d = g.pieceDiameter
        let dx = to.x - from.x, dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1 else { return }
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux  // 垂直方向

        let headLen = d * 0.44, headWidth = d * 0.46
        let start = CGPoint(x: from.x + ux * d * 0.2, y: from.y + uy * d * 0.2)
        let shaftEnd = CGPoint(x: to.x - ux * headLen * 0.75, y: to.y - uy * headLen * 0.75)

        var shaft = Path()
        shaft.move(to: start)
        shaft.addLine(to: shaftEnd)
        ctx.stroke(shaft, with: .color(color.opacity(alpha)),
                   style: StrokeStyle(lineWidth: width, lineCap: .round))

        let tip = to
        let base = CGPoint(x: to.x - ux * headLen, y: to.y - uy * headLen)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: base.x + px * headWidth / 2, y: base.y + py * headWidth / 2))
        head.addLine(to: CGPoint(x: base.x - px * headWidth / 2, y: base.y - py * headWidth / 2))
        head.closeSubpath()
        ctx.fill(head, with: .color(color.opacity(alpha)))
        ctx.stroke(head, with: .color(color.opacity(alpha)),
                   style: StrokeStyle(lineWidth: 1, lineJoin: .round))
    }

    // MARK: - 静态棋盘

    private func drawBoard(_ ctx: inout GraphicsContext, g: BoardGeometry) {
        let f = g.frame
        let cw = f.width / 8
        let ch = f.height / 9
        let x0 = f.minX, y0 = f.minY
        let x8 = f.maxX, y9 = f.maxY
        let y4 = y0 + ch * 4  // 河界

        // 底色 + 木纹（向外扩，落在边线上的棋子不被裁切）
        let wood = f.insetBy(dx: -cw * 0.5, dy: -ch * 0.5)
        ctx.fill(Path(wood), with: .color(SColor(red: 0.885, green: 0.765, blue: 0.53)))
        drawWoodGrain(&ctx, in: wood)

        // 双线边框：外细线 + 内粗线
        var outer = Path()
        outer.addRect(f.insetBy(dx: -cw * 0.16, dy: -ch * 0.16))
        ctx.stroke(outer, with: .color(inkLine.opacity(0.85)), lineWidth: 1)
        var border = Path()
        border.addRect(f)
        ctx.stroke(border, with: .color(inkLine), lineWidth: 2.5)

        var path = Path()
        // 内部横线 8 条
        for r in 1...8 {
            let y = y0 + ch * CGFloat(r)
            path.move(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: x8, y: y))
        }
        // 竖线：中间 7 条被河界断开
        for c in 1...7 {
            let x = x0 + cw * CGFloat(c)
            path.move(to: CGPoint(x: x, y: y0))
            path.addLine(to: CGPoint(x: x, y: y4))
            path.move(to: CGPoint(x: x, y: y4 + ch))
            path.addLine(to: CGPoint(x: x, y: y9))
        }
        // 九宫斜线
        for (rf, rt) in [(0, 2), (7, 9)] {
            let yA = y0 + ch * CGFloat(rf), yB = y0 + ch * CGFloat(rt)
            let xm = x0 + cw * 3, xM = x0 + cw * 5
            path.move(to: CGPoint(x: xm, y: yA)); path.addLine(to: CGPoint(x: xM, y: yB))
            path.move(to: CGPoint(x: xM, y: yA)); path.addLine(to: CGPoint(x: xm, y: yB))
        }
        ctx.stroke(path, with: .color(inkLine.opacity(0.9)), lineWidth: 1)

        // 河界文案：居中渲染
        let riverRect = CGRect(x: x0, y: y4, width: f.width, height: ch)
        let riverText = Text("扶  老  奶  奶  过  马  路")
            .font(.custom("Kaiti SC", size: ch * 0.52))
            .foregroundColor(inkLine.opacity(0.7))
        let resolved = ctx.resolve(riverText)
        let tSize = resolved.measure(in: CGSize(width: f.width, height: ch))
        ctx.draw(resolved, in: CGRect(
            x: f.midX - tSize.width / 2,
            y: riverRect.midY - tSize.height / 2,
            width: tSize.width,
            height: tSize.height
        ))

        // 炮位/兵位标记：四向短杠，中间留缺口
        let positions: [(Int, Int)] = [(1, 2), (7, 2), (0, 3), (2, 3), (4, 3), (6, 3), (8, 3),
                                       (1, 7), (7, 7), (0, 6), (2, 6), (4, 6), (6, 6), (8, 6)]
        var marks = Path()
        let d = cw * 0.18, gap = cw * 0.07
        for (c, r) in positions {
            let x = x0 + cw * CGFloat(c)
            let y = y0 + ch * CGFloat(r)
            // 左右短杠（边缘点只画朝内一侧）
            if c == 0 {
                marks.move(to: CGPoint(x: x + gap, y: y)); marks.addLine(to: CGPoint(x: x + gap + d, y: y))
            } else if c == 8 {
                marks.move(to: CGPoint(x: x - gap, y: y)); marks.addLine(to: CGPoint(x: x - gap - d, y: y))
            } else {
                marks.move(to: CGPoint(x: x + gap, y: y)); marks.addLine(to: CGPoint(x: x + gap + d, y: y))
                marks.move(to: CGPoint(x: x - gap, y: y)); marks.addLine(to: CGPoint(x: x - gap - d, y: y))
            }
            // 上下短杠
            marks.move(to: CGPoint(x: x, y: y + gap)); marks.addLine(to: CGPoint(x: x, y: y + gap + d))
            marks.move(to: CGPoint(x: x, y: y - gap)); marks.addLine(to: CGPoint(x: x, y: y - gap - d))
        }
        ctx.stroke(marks, with: .color(inkLine),
                   style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
    }
}

/// 可吃目标：四角框。
private struct CaptureCorners: View {
    let diameter: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let d = min(size.width, size.height)
            let half = d / 2
            let len = d * 0.22
            let inset = d * 0.06
            var p = Path()
            for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
                let cx = half + CGFloat(sx) * (half - inset)
                let cy = half + CGFloat(sy) * (half - inset)
                p.move(to: CGPoint(x: cx - CGFloat(sx) * len, y: cy))
                p.addLine(to: CGPoint(x: cx, y: cy))
                p.addLine(to: CGPoint(x: cx, y: cy - CGFloat(sy) * len))
            }
            ctx.stroke(p, with: .color(vermilion), lineWidth: 2.4)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// 可走空点：实心点 + 外圈，带呼吸动画。
private struct TargetDot: View {
    let diameter: CGFloat
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(SColor.accentColor.opacity(0.35), lineWidth: 1.5)
            Circle()
                .fill(SColor.accentColor.opacity(0.6))
                .frame(width: diameter * 0.5, height: diameter * 0.5)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(pulsing ? 1.12 : 0.92)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
        .onAppear { pulsing = true }
    }
}

/// 单个棋子：拟木立体圆盘 + 刻环 + 高光 + 书法字。
struct PieceView: View {
    let piece: Piece
    let diameter: CGFloat

    private var glyphColor: SColor {
        piece.color == .red
            ? SColor(red: 0.72, green: 0.10, blue: 0.08)
            : SColor(red: 0.10, green: 0.07, blue: 0.05)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [SColor(red: 0.97, green: 0.81, blue: 0.52),
                             SColor(red: 0.91, green: 0.70, blue: 0.37),
                             SColor(red: 0.74, green: 0.52, blue: 0.22)],
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 0, endRadius: diameter * 0.78))
            // 内阴影沉角：一圈细深色描在略内缩处，朝圆心方向柔化
            Circle()
                .stroke(SColor.black.opacity(0.25), lineWidth: diameter * 0.03)
                .padding(diameter * 0.015)
                .blur(radius: diameter * 0.012)
            // 顶部高光弧
            Circle()
                .trim(from: 0.58, to: 0.72)
                .stroke(SColor.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: diameter * 0.03, lineCap: .round))
                .padding(diameter * 0.11)
            Text(piece.glyph)
                .font(.custom("Kaiti SC", size: diameter * 0.56).weight(.bold))
                .foregroundColor(glyphColor)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.35), radius: diameter * 0.07,
                x: diameter * 0.025, y: diameter * 0.06)
    }
}
