import AppKit

/// Desk FM's mark: a desk lamp whose glow is three sound waves — light for working,
/// sound for the music. Shared by the menu bar icon and scripts/make-icon.
enum LampGlyph {
    /// Drawn on a 24×24 grid with y pointing down, then fitted into `rect`.
    /// `lamp` colours the base, arm and shade; `light` colours the sound waves.
    static func draw(in rect: NSRect, lamp: NSColor, light: NSColor) {
        // The shade points right and a little down; the waves are centred on that
        // beam, so they spread to the right and stay well clear of the base.
        let beam: CGFloat = 30                  // degrees below horizontal
        let rad = beam * .pi / 180
        let d = CGPoint(x: cos(rad), y: sin(rad))   // shade axis
        let p = CGPoint(x: sin(rad), y: -cos(rad))  // perpendicular to it
        func pt(_ base: CGPoint, _ a: CGFloat, along v: CGPoint) -> CGPoint {
            CGPoint(x: base.x + a * v.x, y: base.y + a * v.y)
        }
        let back = CGPoint(x: 8, y: 6)          // narrow end of the shade
        let mouth = pt(back, 4.6, along: d)     // centre of the shade's opening

        func stroked(_ points: [CGPoint], width: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            return path
        }

        // Base and two-segment arm: down-left to the elbow, then up into the shade.
        let base = stroked([CGPoint(x: 3, y: 20), CGPoint(x: 11, y: 20)], width: 2.4)
        let arm = stroked([CGPoint(x: 7, y: 20), CGPoint(x: 4.4, y: 12.6), pt(back, 0.9, along: d)], width: 2.2)

        // Shade: a cone, narrow at the back and open towards the beam.
        let shade = NSBezierPath()
        shade.move(to: pt(back, 1.4, along: p))
        shade.line(to: pt(mouth, 3.4, along: p))
        shade.line(to: pt(mouth, -3.4, along: p))
        shade.line(to: pt(back, -1.4, along: p))
        shade.close()
        shade.lineWidth = 1.2
        shade.lineJoinStyle = .round

        // Three sound waves, evenly spaced and symmetric around the beam.
        let source = pt(mouth, -0.8, along: d)
        let rays: [NSBezierPath] = [3.7, 6.0, 8.3].map { radius in
            let wave = NSBezierPath()
            wave.appendArc(withCenter: source, radius: radius, startAngle: beam - 34, endAngle: beam + 34)
            wave.lineWidth = 1.5
            wave.lineCapStyle = .round
            return wave
        }

        // Fit the 24-grid drawing (y down) into rect (y up), centred.
        var t = AffineTransform()
        t.translate(x: rect.minX, y: rect.maxY)
        t.scale(x: rect.width / 24, y: -rect.height / 24)
        t.translate(x: 0.6, y: -0.6)            // centre the artwork in the grid
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
