// Renders the app icon to an .iconset folder. Compiled together with LampGlyph.swift by build.sh:
//   swiftc Sources/DeskFM/LampGlyph.swift scripts/make-icon/main.swift -o <tool> && <tool> <out.iconset>
import AppKit

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // macOS icon grid: 824pt rounded square centred on a 1024 canvas.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    // "Paper": cream tile, slate lamp, orange sound waves.
    NSGradient(starting: NSColor(srgbRed: 0.94, green: 0.89, blue: 0.82, alpha: 1),   // #EFE4D2
               ending: NSColor(srgbRed: 0.90, green: 0.85, blue: 0.77, alpha: 1))!
        .draw(in: tilePath, angle: -90)
    // A faint edge so the light tile doesn't dissolve into white windows.
    NSColor(srgbRed: 0.18, green: 0.28, blue: 0.35, alpha: 0.12).setStroke()
    tilePath.lineWidth = 4 * s
    tilePath.stroke()

    LampGlyph.draw(in: tile.insetBy(dx: 70 * s, dy: 70 * s),
                   lamp: NSColor(srgbRed: 0.18, green: 0.28, blue: 0.35, alpha: 1),    // #2F4858
                   light: NSColor(srgbRed: 0.89, green: 0.41, blue: 0.29, alpha: 1))   // #E2694A

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = renderIcon(pixels: points * scale).representation(using: .png, properties: [:])!
        try! png.write(to: out.appendingPathComponent(name))
    }
}
