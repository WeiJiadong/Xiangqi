// 生成 macOS App 图标：源图 → 圆角方块 + 投影 → AppIcon.icns
// 用法: swift scripts/make_icon.swift <源图> <输出.icns>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("用法: make_icon.swift <源图> <输出.icns>\n", stderr)
    exit(1)
}
let srcURL = URL(fileURLWithPath: args[1])
let outPath = args[2]
let workDir = URL(fileURLWithPath: "build/AppIconWork")

// macOS 规范：1024 画布，824 圆角方块，圆角 185.4，四周留 100 边距
let canvas: CGFloat = 1024
let tileSide: CGFloat = 824
let cornerRadius: CGFloat = 185.4
let margin = (canvas - tileSide) / 2

guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fputs(">> 读取源图失败\n", stderr)
    exit(1)
}

guard let ctx = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs(">> 建画布失败\n", stderr)
    exit(1)
}

let tile = CGRect(x: margin, y: margin, width: tileSide, height: tileSide)
let rounded = CGPath(roundedRect: tile, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// 底层：白底圆角块 + 向下投影（CG 坐标系 y 轴朝上，offset 取负即视觉向下）
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25))
ctx.setFillColor(CGColor(srgbRed: 0.96, green: 0.93, blue: 0.88, alpha: 1))
ctx.addPath(rounded)
ctx.fillPath()
ctx.restoreGState()

// 圆角裁剪内铺源图（源图为正方形，等比铺满）
ctx.saveGState()
ctx.addPath(rounded)
ctx.clip()
ctx.draw(image, in: tile)
ctx.restoreGState()

guard let master = ctx.makeImage() else {
    fputs(">> 导出失败\n", stderr)
    exit(1)
}

try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
let masterURL = workDir.appendingPathComponent("master_1024.png")
guard let dest = CGImageDestinationCreateWithURL(masterURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fputs(">> 建输出失败\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, master, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs(">> 写 PNG 失败\n", stderr)
    exit(1)
}

func run(_ tool: String, _ arguments: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = arguments
    try? p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else {
        fputs(">> \(tool) 执行失败\n", stderr)
        exit(1)
    }
}

// iconset 全尺寸（含 @2x）
let iconset = workDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, side) in sizes {
    run("/usr/bin/sips", ["-z", "\(side)", "\(side)", masterURL.path, "--out", iconset.appendingPathComponent(name).path])
}
try? FileManager.default.removeItem(at: URL(fileURLWithPath: outPath))
run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", outPath])
print(">> icns 已生成：\(outPath)")
