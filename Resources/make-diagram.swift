import AppKit
import CoreGraphics

// 生成「多输出设备 vs 分频输出」对比示意图（1600x900）
// 用法：swift make-diagram.swift，输出 docs/diagram-why.png

let W: CGFloat = 1600, H: CGFloat = 900
let S: CGFloat = 2          // 2x 超采样，导出 3200x1800，文字更锐
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * S), pixelsHigh: Int(H * S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
cg.scaleBy(x: S, y: S)
cg.setShouldAntialias(true)
// AppKit 的画布本身就是左下原点、y 向上。这里不改 CTM，
// 而是在绘图 helper 内部把「左上原点」坐标换算过去，避免文本被镜像。

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func flip(_ r: CGRect) -> CGRect {
    CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height)
}

func fill(_ r0: CGRect, _ color: NSColor, radius: CGFloat = 0) {
    let r = flip(r0)
    color.setFill()
    if radius > 0 { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill() }
    else { r.fill() }
}

func stroke(_ r0: CGRect, _ color: NSColor, radius: CGFloat = 0, width: CGFloat = 1) {
    color.setStroke()
    let p = NSBezierPath(roundedRect: flip(r0), xRadius: radius, yRadius: radius)
    p.lineWidth = width
    p.stroke()
}

func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
          weight: NSFont.Weight = .regular, color: NSColor = .black,
          align: NSTextAlignment = .center, width: CGFloat = 0, mono: Bool = false) {
    let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    let ps = NSMutableParagraphStyle()
    ps.alignment = align
    ps.lineSpacing = 3
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: ps]
    let str = NSAttributedString(string: s, attributes: attrs)
    let box = str.boundingRect(with: NSSize(width: width > 0 ? width : W, height: 400),
                              options: [.usesLineFragmentOrigin, .usesFontLeading])
    let drawX = align == .center ? x - box.width / 2 : x
    // y 是「距画布顶部」的距离，换成底部原点后要减掉自身高度
    str.draw(with: NSRect(x: drawX, y: H - y - box.height, width: max(box.width, width), height: box.height),
             options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func arrowRaw(_ from: CGPoint, _ to: CGPoint, _ color: NSColor, width: CGFloat = 2.5, head: CGFloat = 11) {
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.move(to: from)
    path.line(to: to)
    path.stroke()

    let ang = atan2(to.y - from.y, to.x - from.x)
    let p = NSBezierPath()
    p.move(to: to)
    p.line(to: CGPoint(x: to.x - head * cos(ang - .pi / 7), y: to.y - head * sin(ang - .pi / 7)))
    p.line(to: CGPoint(x: to.x - head * cos(ang + .pi / 7), y: to.y - head * sin(ang + .pi / 7)))
    p.close()
    color.setFill()
    p.fill()
}

func arrow(_ from: CGPoint, _ to: CGPoint, _ color: NSColor, width: CGFloat = 2.5, head: CGFloat = 11) {
    arrowRaw(CGPoint(x: from.x, y: H - from.y), CGPoint(x: to.x, y: H - to.y), color, width: width, head: head)
}

/// 折线箭头：先竖后横（用于分叉）。坐标同样是左上原点。
func elbow(_ from: CGPoint, _ to: CGPoint, _ color: NSColor, width: CGFloat = 2.5) {
    let f = CGPoint(x: from.x, y: H - from.y)
    let t = CGPoint(x: to.x, y: H - to.y)
    let mid = CGPoint(x: f.x, y: t.y)
    color.setStroke()
    let path = NSBezierPath()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: f)
    path.line(to: mid)
    path.stroke()
    arrowRaw(mid, t, color, width: width)
}

// ── 画布底色
fill(CGRect(x: 0, y: 0, width: W, height: H), rgb(0xFFFFFF))

let panelW: CGFloat = 730, gapX: CGFloat = 60
let leftX: CGFloat = (W - panelW * 2 - gapX) / 2
let rightX = leftX + panelW + gapX
let topY: CGFloat = 42
let panelH: CGFloat = 816

// ── 面板
fill(CGRect(x: leftX, y: topY, width: panelW, height: panelH), rgb(0xFAFAFC), radius: 26)
stroke(CGRect(x: leftX, y: topY, width: panelW, height: panelH), rgb(0xE7E7EE), radius: 26, width: 1.5)
fill(CGRect(x: rightX, y: topY, width: panelW, height: panelH), rgb(0xFBF9FF), radius: 26)
stroke(CGRect(x: rightX, y: topY, width: panelW, height: panelH), rgb(0xE4DDFF), radius: 26, width: 1.5)

// ── 左：多输出设备
let lcx = leftX + panelW / 2
fill(CGRect(x: lcx - 128, y: topY + 30, width: 256, height: 34), rgb(0xFFECEB), radius: 17)
text("macOS 多输出设备", lcx, topY + 38, 17, weight: .semibold, color: rgb(0xD93A2B))
text("同一路全频，复制给两只喇叭", lcx, topY + 82, 22, weight: .semibold, color: rgb(0x1C1C22))

// 源
let srcL = CGRect(x: lcx - 110, y: topY + 140, width: 220, height: 62)
fill(srcL, rgb(0xEDEDF3), radius: 14)
text("系统音频 · 全频", lcx, topY + 158, 17, weight: .medium, color: rgb(0x3C3C46))

// 分叉到两只喇叭
let spkA = CGRect(x: leftX + 60, y: topY + 330, width: 250, height: 92)
let spkB = CGRect(x: leftX + panelW - 310, y: topY + 330, width: 250, height: 92)
elbow(CGPoint(x: lcx - 26, y: topY + 202), CGPoint(x: spkA.midX, y: spkA.minY - 12), rgb(0xC9C9D4))
elbow(CGPoint(x: lcx + 26, y: topY + 202), CGPoint(x: spkB.midX, y: spkB.minY - 12), rgb(0xC9C9D4))
fill(spkA, rgb(0xFFFFFF), radius: 14); stroke(spkA, rgb(0xD9D9E2), radius: 14, width: 1.5)
fill(spkB, rgb(0xFFFFFF), radius: 14); stroke(spkB, rgb(0xD9D9E2), radius: 14, width: 1.5)
text("内置喇叭", spkA.midX, spkA.minY + 22, 18, weight: .semibold, color: rgb(0x1C1C22))
text("全频 20Hz–20kHz", spkA.midX, spkA.minY + 48, 13, color: rgb(0x8A8A96))
text("外接音箱", spkB.midX, spkB.minY + 22, 18, weight: .semibold, color: rgb(0x1C1C22))
text("全频 20Hz–20kHz", spkB.midX, spkB.minY + 48, 13, color: rgb(0x8A8A96))

// 交点标记（低频重叠）
let overlapY = topY + 452
text("低频被播了两遍", lcx, overlapY + 30, 15, weight: .medium, color: rgb(0xD93A2B))
fill(CGRect(x: lcx - 92, y: overlapY + 56, width: 184, height: 30), rgb(0xFFECEB), radius: 15)
text("80Hz 时两只都在响", lcx, overlapY + 63, 13, color: rgb(0xD93A2B))

// 问题清单
let issues = [
    ("低频叠加", "同一段低频从两只喇叭同时出来，相位稍差就互抵或堆积"),
    ("分频点打架", "内置喇叭硬扛 80Hz，纸盆位移到极限，中频跟着糊"),
    ("路径不等长", "两条链路延迟不同，鼓点出现「双击」"),
]
var iy = topY + 556
for (k, v) in issues {
    fill(CGRect(x: leftX + 60, y: iy + 4, width: 5, height: 5), rgb(0xD93A2B), radius: 2.5)
    text(k, leftX + 80, iy - 6, 16, weight: .semibold, color: rgb(0x2A2A32), align: .left, width: 180)
    text(v, leftX + 80, iy + 20, 14, color: rgb(0x71717E), align: .left, width: panelW - 150)
    iy += 68
}

// ── 右：分频输出
let rcx = rightX + panelW / 2
fill(CGRect(x: rcx - 118, y: topY + 30, width: 236, height: 34), rgb(0xF0EBFF), radius: 17)
text("MultiSpeaker", rcx, topY + 38, 17, weight: .semibold, color: rgb(0x6A4BE8))
text("先切开频段，再分别送出去", rcx, topY + 82, 22, weight: .semibold, color: rgb(0x1C1C22))

let srcR = CGRect(x: rcx - 110, y: topY + 140, width: 220, height: 62)
fill(srcR, rgb(0xEDEDF3), radius: 14)
text("系统音频 · 全频", rcx, topY + 158, 17, weight: .medium, color: rgb(0x3C3C46))

// 分频器
let xover = CGRect(x: rcx - 132, y: topY + 236, width: 264, height: 68)
let grad = NSGradient(starting: rgb(0x8B6BFF), ending: rgb(0x5B4BE0))!
grad.draw(in: NSBezierPath(roundedRect: flip(xover), xRadius: 16, yRadius: 16), angle: 90)
text("LR4 分频 · 200Hz", rcx, topY + 254, 17, weight: .semibold, color: .white)
text("24dB/oct，分频点同相", rcx, topY + 278, 12, color: rgb(0xEDE8FF))
arrow(CGPoint(x: rcx, y: srcR.maxY + 8), CGPoint(x: rcx, y: xover.minY - 10), rgb(0xB9A8FF))

// 两路
let hpBox = CGRect(x: rightX + 58, y: topY + 352, width: 250, height: 100)
let lpBox = CGRect(x: rightX + panelW - 308, y: topY + 352, width: 250, height: 100)
elbow(CGPoint(x: rcx - 30, y: xover.maxY + 6), CGPoint(x: hpBox.midX, y: hpBox.minY - 12), rgb(0xFF9F0A))
elbow(CGPoint(x: rcx + 30, y: xover.maxY + 6), CGPoint(x: lpBox.midX, y: lpBox.minY - 12), rgb(0x5B6CFF))
fill(hpBox, rgb(0xFFF6E8), radius: 14); stroke(hpBox, rgb(0xFFD9A0), radius: 14, width: 1.5)
fill(lpBox, rgb(0xEDEFFF), radius: 14); stroke(lpBox, rgb(0xC3CAFF), radius: 14, width: 1.5)
text("内置喇叭", hpBox.midX, hpBox.minY + 20, 17, weight: .semibold, color: rgb(0x9A6A00))
text("高通 · 200Hz 以上", hpBox.midX, hpBox.minY + 44, 13, color: rgb(0xA97F2E))
text("+ 延迟 8ms 对齐", hpBox.midX, hpBox.minY + 66, 13, weight: .medium, color: rgb(0x9A6A00))
text("外接音箱", lpBox.midX, lpBox.minY + 20, 17, weight: .semibold, color: rgb(0x3A45B8))
text("低通 · 200Hz 以下", lpBox.midX, lpBox.minY + 44, 13, color: rgb(0x5B6CFF))
text("只推它擅长的低频", lpBox.midX, lpBox.minY + 66, 13, weight: .medium, color: rgb(0x3A45B8))

// 频段分工示意条
let bx: CGFloat = rightX + 58, bw = panelW - 116
let by = topY + 490
text("实际频谱分工", bx, by - 26, 13, weight: .medium, color: rgb(0x71717E), align: .left, width: 200)
fill(CGRect(x: bx, y: by, width: bw / 2, height: 26), rgb(0xFFB340), radius: 6)
fill(CGRect(x: bx + bw / 2, y: by, width: bw / 2, height: 26), rgb(0x7B8CFF), radius: 6)
text("高频 / 中频 → 笔记本", bx + bw / 4, by + 5, 12, weight: .medium, color: .white)
text("低频 → 音箱", bx + bw * 0.75, by + 5, 12, weight: .medium, color: .white)

// 收益
let gains = [
    ("每段频率只响一次", "没有重复的低频，鼓点干净，人声不再糊"),
    ("分频点平直交接", "高通与低通在 f_c 各衰减 6dB 且同相，合起来正好 0dB"),
    ("延迟可调", "内置喇叭快，加 0–40ms 让两条链路同时到达耳朵"),
]
iy = topY + 556
for (k, v) in gains {
    fill(CGRect(x: rightX + 60, y: iy + 4, width: 5, height: 5), rgb(0x21B573), radius: 2.5)
    text(k, rightX + 80, iy - 6, 16, weight: .semibold, color: rgb(0x2A2A32), align: .left, width: 200)
    text(v, rightX + 80, iy + 20, 14, color: rgb(0x71717E), align: .left, width: panelW - 150)
    iy += 68
}

// 底部结论条
func footer(_ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, fg: NSColor, bg: NSColor) {
    fill(CGRect(x: x, y: y, width: w, height: 46), bg, radius: 12)
    text(s, x + w / 2, y + 12, 15, weight: .semibold, color: fg)
}
footer("两只喇叭互相拖后腿", leftX + 40, topY + panelH - 66, panelW - 80,
       fg: rgb(0xD93A2B), bg: rgb(0xFFEFEE))
footer("两只喇叭各司其职", rightX + 40, topY + panelH - 66, panelW - 80,
       fg: rgb(0x1B8F5C), bg: rgb(0xEAF9F1))

// 输出
let out = URL(fileURLWithPath: "docs/diagram-why.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("written \(out.path)")
