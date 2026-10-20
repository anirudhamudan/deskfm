import AppKit

/// Monochrome Spotify mark (circle with three sound arcs), drawn as a template
/// image so it matches the other menu bar icons in light and dark mode.
enum SpotifyGlyph {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()

            // Knock the arcs out of the filled circle.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            // Quadratic arcs traced from the reference logo: flat on the left,
            // dropping away on the right.
            let arcs: [(start: NSPoint, control: NSPoint, end: NSPoint, width: CGFloat)] = [
                (NSPoint(x: 3.8, y: 11.8), NSPoint(x: 6.8, y: 13.9), NSPoint(x: 14.4, y: 10.5), 1.8),
                (NSPoint(x: 4.4, y: 9.1),  NSPoint(x: 7.7, y: 11.0), NSPoint(x: 13.2, y: 8.0),  1.55),
                (NSPoint(x: 4.8, y: 6.5),  NSPoint(x: 7.4, y: 8.2),  NSPoint(x: 12.3, y: 5.45), 1.3),
            ]
            for arc in arcs {
                // Convert the quadratic control point to cubic ones.
                let c1 = NSPoint(x: arc.start.x + 2 / 3 * (arc.control.x - arc.start.x),
                                 y: arc.start.y + 2 / 3 * (arc.control.y - arc.start.y))
                let c2 = NSPoint(x: arc.end.x + 2 / 3 * (arc.control.x - arc.end.x),
                                 y: arc.end.y + 2 / 3 * (arc.control.y - arc.end.y))
                let path = NSBezierPath()
                path.move(to: arc.start)
                path.curve(to: arc.end, controlPoint1: c1, controlPoint2: c2)
                path.lineWidth = arc.width
                path.lineCapStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
