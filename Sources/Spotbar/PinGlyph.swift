import AppKit

/// Spotbar's mark: a pushpin, because the whole point is that the controls stay
/// pinned to the menu bar. Shared by the menu bar icon and scripts/make-icon.swift.
enum PinGlyph {
    /// Pushpin silhouette tilted 45°, scaled to fill `rect` (designed on an 18×18 grid).
    static func path(in rect: NSRect) -> NSBezierPath {
        let p = NSBezierPath()
        p.append(NSBezierPath(roundedRect: NSRect(x: 5.5, y: 14, width: 7, height: 2.5), xRadius: 1.2, yRadius: 1.2)) // cap
        p.append(NSBezierPath(rect: NSRect(x: 6.75, y: 9.4, width: 4.5, height: 4.8)))                                  // body
        p.append(NSBezierPath(roundedRect: NSRect(x: 4, y: 8, width: 10, height: 1.8), xRadius: 0.9, yRadius: 0.9))    // collar
        p.append(NSBezierPath(roundedRect: NSRect(x: 8.4, y: 1.5, width: 1.2, height: 7), xRadius: 0.6, yRadius: 0.6)) // needle

        var tilt = AffineTransform()
        tilt.translate(x: 9, y: 9)
        tilt.rotate(byDegrees: -45)
        tilt.translate(x: -9, y: -9)
        p.transform(using: tilt)

        var fit = AffineTransform()
        fit.translate(x: rect.minX, y: rect.minY)
        fit.scale(rect.width / 18)
        p.transform(using: fit)
        return p
    }

    /// Template image for the menu bar, so it follows light and dark mode.
    static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setFill()
            path(in: rect).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
