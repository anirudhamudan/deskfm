// Renders the app icon to an .iconset folder. Compiled together with PinGlyph.swift by build.sh:
//   swiftc Sources/Spotbar/PinGlyph.swift scripts/make-icon/main.swift -o <tool> && <tool> <out.iconset>
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
    NSGradient(starting: NSColor(srgbRed: 0.17, green: 0.18, blue: 0.22, alpha: 1),
               ending: NSColor(srgbRed: 0.09, green: 0.10, blue: 0.12, alpha: 1))!
        .draw(in: tilePath, angle: -90)

    let pinRect = tile.insetBy(dx: 115 * s, dy: 115 * s)
    let pin = PinGlyph.path(in: pinRect)
    NSGradient(starting: NSColor(srgbRed: 1.0, green: 0.42, blue: 0.36, alpha: 1),
               ending: NSColor(srgbRed: 0.86, green: 0.22, blue: 0.24, alpha: 1))!
        .draw(in: pin, angle: -90)

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
