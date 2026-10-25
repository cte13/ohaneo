import AppKit
import CoreText

// Renders the app icon (light and dark). Usage:
// swift Tools/icon/render_icon.swift Ohaneo/Resources/Fonts/GowunBatang-Bold.ttf <outDir>
// b-three.png → AppIcon.png, b-three-dark.png → AppIcon-Dark.png
let args = CommandLine.arguments
let fontURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

struct Palette { let paper, cell, grid, ink, red: UInt32 }
let light = Palette(paper: 0xF6F8F4, cell: 0xFFFFFF, grid: 0x3D8A64, ink: 0x1F2B47, red: 0xC2362B)
let dark = Palette(paper: 0x121815, cell: 0x1A221E, grid: 0x5FAE87, ink: 0xE7ECE6, red: 0xFF6F61)

func draw(text: String, palette p: Palette, name: String) {
    let size = 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(color(p.paper)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let chars = Array(text)
    let n = CGFloat(chars.count)
    let cell: CGFloat = n == 1 ? 600 : 290
    let total = cell * n
    let x0 = (CGFloat(size) - total) / 2
    let y0 = (CGFloat(size) - cell) / 2 + 30   // nudge up to leave room for the underline

    for (i, ch) in chars.enumerated() {
        let rect = CGRect(x: x0 + CGFloat(i) * cell, y: y0, width: cell, height: cell)
        ctx.setFillColor(color(p.cell)); ctx.fill(rect)
        let font = CTFontCreateWithName("GowunBatang-Bold" as CFString, cell * 0.72, nil)
        let attr = NSAttributedString(string: String(ch), attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(p.ink),
        ])
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(x: rect.midX - bounds.width / 2 - bounds.minX,
                                   y: rect.midY - bounds.height / 2 - bounds.minY)
        CTLineDraw(line, ctx)
    }
    // Grid lines
    ctx.setStrokeColor(color(p.grid)); ctx.setLineWidth(n == 1 ? 18 : 12)
    ctx.stroke(CGRect(x: x0, y: y0, width: total, height: cell))
    for i in 1..<chars.count {
        let x = x0 + CGFloat(i) * cell
        ctx.move(to: CGPoint(x: x, y: y0)); ctx.addLine(to: CGPoint(x: x, y: y0 + cell))
    }
    ctx.strokePath()
    // Red-pen underline below the grid
    ctx.setStrokeColor(color(p.red)); ctx.setLineWidth(n == 1 ? 26 : 20); ctx.setLineCap(.round)
    let uy = y0 - (n == 1 ? 70 : 60)
    let inset: CGFloat = n == 1 ? 90 : 40
    ctx.move(to: CGPoint(x: x0 + inset, y: uy)); ctx.addLine(to: CGPoint(x: x0 + total - inset, y: uy))
    ctx.strokePath()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

draw(text: "오", palette: light, name: "a-single.png")
draw(text: "오한어", palette: light, name: "b-three.png")
draw(text: "오", palette: dark, name: "a-single-dark.png")
draw(text: "오한어", palette: dark, name: "b-three-dark.png")
print("done")
