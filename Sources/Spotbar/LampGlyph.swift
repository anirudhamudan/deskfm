import AppKit

/// Spotbar's mark: a desk lamp throwing three rays of light — the thing you switch on
/// when you sit down to focus. Shared by the menu bar icon and scripts/make-icon.
enum LampGlyph {
    /// Drawn on a 24×24 grid with y pointing down, then fitted into `rect`.
    /// `lamp` colours the base, arm and shade; `light` colours the rays.
    static func draw(in rect: NSRect, lamp: NSColor, light: NSColor) {
        let d = CGPoint(x: 0.7071, y: 0.7071)   // shade axis, pointing down-right
        let p = CGPoint(x: 0.7071, y: -0.7071)  // perpendicular to it
        func pt(_ base: CGPoint, _ a: CGFloat, along v: CGPoint, _ b: CGFloat = 0, along w: CGPoint = .zero) -> CGPoint {
            CGPoint(x: base.x + a * v.x + b * w.x, y: base.y + a * v.y + b * w.y)
        }
        let back = CGPoint(x: 6.5, y: 6.5)      // where the arm meets the shade
        let mouth = CGPoint(x: 11, y: 11)       // centre of the shade's opening

        func stroked(_ points: [CGPoint], width: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            return path
        }

        // Base and two-segment arm.
        let base = stroked([CGPoint(x: 3, y: 21), CGPoint(x: 11, y: 21)], width: 2.4)
        let arm = stroked([CGPoint(x: 6, y: 21), CGPoint(x: 3.8, y: 13.5), back], width: 2.2)

        // Shade: a cone, narrow at the back and open towards the light.
        let shade = NSBezierPath()
        shade.move(to: pt(back, 1.5, along: p))
        shade.line(to: pt(mouth, 3.7, along: p))
        shade.line(to: pt(mouth, -3.7, along: p))
        shade.line(to: pt(back, -1.5, along: p))
        shade.close()
        shade.lineWidth = 1.2
        shade.lineJoinStyle = .round

        // Three rays fanning out of the opening.
        func ray(offset: CGFloat, angle: CGFloat, length: CGFloat) -> NSBezierPath {
            let start = pt(mouth, 2.6, along: d, offset, along: p)
            let dir = CGPoint(x: cos(angle * .pi / 180), y: sin(angle * .pi / 180))
            return stroked([start, pt(start, length, along: dir)], width: 1.5)
        }
        let rays = [ray(offset: 3.4, angle: 8, length: 2.8),
                    ray(offset: 0, angle: 45, length: 3.0),
                    ray(offset: -3.4, angle: 82, length: 2.8)]

        // Fit the 24-grid drawing (y down) into rect (y up), centred.
        var t = AffineTransform()
        t.translate(x: rect.minX, y: rect.maxY)
        t.scale(x: rect.width / 24, y: -rect.height / 24)
        t.translate(x: 1.6, y: -2.0)            // centre the artwork in the grid
        for path in [base, arm, shade] + rays {
            path.transform(using: t)
            path.lineWidth *= rect.width / 24     // transforms don't scale stroke widths
        }

        lamp.set()
        base.stroke(); arm.stroke()
        shade.fill(); shade.stroke()
        light.set()
        rays.forEach { $0.stroke() }
    }

    /// Template image for the menu bar, so it follows light and dark mode.
    static let menuBarImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect, lamp: .black, light: .black)
            return true
        }
        image.isTemplate = true
        return image
    }()
}
