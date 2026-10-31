// Draws the సం app icon and writes an .iconset folder for iconutil, or with --web the PNGs
// for the web app (icon-192/512 plus a full-bleed maskable-512 for Android).
// Usage: swift scripts/make_icon.swift OUT.iconset
//        swift scripts/make_icon.swift --web OUT_DIR
import AppKit

enum Style { case mac, web, maskable }

let web = CommandLine.arguments[1] == "--web"
let out = URL(fileURLWithPath: CommandLine.arguments[web ? 2 : 1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int, _ style: Style = .mac) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS icon grid: the tile is inset ~10% with a ~22% corner radius. Android crops
    // maskable icons to its own shape, keeping only the central 80% circle.
    let inset: CGFloat = style == .mac ? 0.1 : style == .web ? 0.02 : 0
    let tile = NSRect(x: s * inset, y: s * inset, width: s * (1 - 2 * inset), height: s * (1 - 2 * inset))
    let radius = style == .maskable ? 0 : tile.width * 0.225
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    NSGradient(colors: [
        NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1),
        NSColor(red: 0.85, green: 0.33, blue: 0.08, alpha: 1),
    ])!.draw(in: path, angle: -90)

    let ctx = NSGraphicsContext.current!.cgContext
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowBlurRadius = s * 0.02
    let cream = NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1)

    // Telugu సం large, Devanagari सं small beneath it: the two scripts of the course.
    let scale = style == .maskable ? 0.78 : tile.width / s
    func draw(_ string: String, fonts: [String], size: CGFloat, centerY: CGFloat, alpha: CGFloat) {
        let font = fonts.lazy.compactMap { NSFont(name: $0, size: size) }.first
            ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        let text = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: cream.withAlphaComponent(alpha), .shadow: shadow,
        ])
        let line = CTLineCreateWithAttributedString(text)
        let glyph = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(x: tile.midX - glyph.midX, y: centerY - glyph.midY)
        CTLineDraw(line, ctx)
    }
    draw("సం", fonts: ["Kohinoor Telugu Semibold", "Telugu Sangam MN Bold", "Telugu MN Bold"],
         size: s * 0.40 * scale, centerY: tile.midY + s * 0.07 * scale, alpha: 1)
    draw("सं", fonts: ["Kohinoor Devanagari Semibold", "Devanagari Sangam MN Bold"],
         size: s * 0.20 * scale, centerY: tile.midY - s * 0.24 * scale, alpha: 0.85)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

if web {
    try render(192, .web).write(to: out.appendingPathComponent("icon-192.png"))
    try render(512, .web).write(to: out.appendingPathComponent("icon-512.png"))
    try render(512, .maskable).write(to: out.appendingPathComponent("maskable-512.png"))
} else {
    for size in [16, 32, 128, 256, 512] {
        try render(size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
        try render(size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
}
