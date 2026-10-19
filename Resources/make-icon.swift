// MultiSpeaker 图标生成器：1024×1024 主图（其他尺寸由 sips 派生，再 iconutil 合成 .icns）
// 设计：靛蓝→紫罗兰渐变圆角底 + 两台音箱（高的带高音/低音单元，矮的单单元），
//       表达「多个喇叭一起用」；无文字、纯几何，16px 下仍可辨认。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// MARK: 底板（macOS 图标留 96px 边距、圆角 186）

let plate = CGRect(x: 96, y: 96, width: S - 192, height: S - 192)
let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()

// 主渐变：顶部亮靛蓝 → 底部深紫
let bg = CGGradient(colorsSpace: cs, colors: [
    rgba(0.478, 0.396, 1.0),
    rgba(0.353, 0.263, 0.902),
    rgba(0.180, 0.114, 0.541),
] as CFArray, locations: [0.0, 0.52, 1.0])!
ctx.drawLinearGradient(bg, start: CGPoint(x: S * 0.5, y: S), end: CGPoint(x: S * 0.5, y: 0), options: [])

// 左上角柔光，避免纯平
let glow = CGGradient(colorsSpace: cs, colors: [
    rgba(1, 1, 1, 0.24), rgba(1, 1, 1, 0.0),
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: 300, y: 840), startRadius: 0,
                       endCenter: CGPoint(x: 300, y: 840), endRadius: 640,
                       options: [])

// MARK: 图形

let white = rgba(1, 1, 1, 1)
ctx.setStrokeColor(white)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// 左：较高的音箱（高音 + 低音单元）
let left = CGRect(x: 246, y: 300, width: 236, height: 440)
ctx.setLineWidth(34)
ctx.addPath(CGPath(roundedRect: left, cornerWidth: 60, cornerHeight: 60, transform: nil))
ctx.strokePath()
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: 364 - 26, y: 650 - 26, width: 52, height: 52))     // 高音单元
ctx.fillEllipse(in: CGRect(x: 364 - 62, y: 470 - 62, width: 124, height: 124))  // 低音单元

// 右：较矮的音箱（单个单元）
let right = CGRect(x: 546, y: 300, width: 232, height: 320)
ctx.addPath(CGPath(roundedRect: right, cornerWidth: 58, cornerHeight: 58, transform: nil))
ctx.strokePath()
ctx.fillEllipse(in: CGRect(x: 662 - 60, y: 460 - 60, width: 120, height: 120))

ctx.restoreGState()

// MARK: 输出 PNG

guard let image = ctx.makeImage() else { exit(1) }
let outURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
                 ? CommandLine.arguments[1]
                 : "AppIcon-1024.png")
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("wrote \(outURL.path)")
