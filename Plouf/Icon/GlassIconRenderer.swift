import AppKit

/// Dessine l'icône de la barre de menus : un verre qui se remplit selon la progression.
/// L'image est en mode « template » : macOS la colore lui-même selon le thème clair/sombre.
enum GlassIconRenderer {
    /// Nombre de paliers de remplissage (0 = vide, `levels` = plein).
    static let levels = 10

    /// Palier correspondant à une progression entre 0 et 1.
    /// Un verre entamé n'apparaît jamais vide, un verre pas tout à fait fini jamais plein.
    static func level(for progress: Double) -> Int {
        let clamped = min(max(progress, 0), 1)
        if clamped <= 0 { return 0 }
        if clamped >= 1 { return levels }
        return min(max(Int((clamped * Double(levels)).rounded()), 1), levels - 1)
    }

    /// Cache des images déjà dessinées, une par palier.
    private static var cache: [Int: NSImage] = [:]

    static func image(progress: Double) -> NSImage {
        let level = level(for: progress)
        if let cached = cache[level] { return cached }
        let image = draw(level: level)
        cache[level] = image
        return image
    }

    private static func draw(level: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            // Verre en forme de trapèze : plus large en haut qu'en bas.
            let bottomY: CGFloat = 2
            let topY: CGFloat = 16
            let bottomInset: CGFloat = 4.5
            let topInset: CGFloat = 2.5
            let lineWidth: CGFloat = 1.5

            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: topInset, y: topY))
            outline.line(to: NSPoint(x: bottomInset, y: bottomY))
            outline.line(to: NSPoint(x: size.width - bottomInset, y: bottomY))
            outline.line(to: NSPoint(x: size.width - topInset, y: topY))
            outline.lineWidth = lineWidth
            outline.lineJoinStyle = .round
            outline.lineCapStyle = .round

            // Eau : même trapèze, découpé à la hauteur du palier.
            if level > 0 {
                let fillTop = bottomY + (topY - 1 - bottomY) * CGFloat(level) / CGFloat(levels)
                NSGraphicsContext.saveGraphicsState()
                let interior = NSBezierPath()
                interior.move(to: NSPoint(x: topInset, y: topY))
                interior.line(to: NSPoint(x: bottomInset, y: bottomY))
                interior.line(to: NSPoint(x: size.width - bottomInset, y: bottomY))
                interior.line(to: NSPoint(x: size.width - topInset, y: topY))
                interior.close()
                interior.addClip()
                NSColor.black.setFill()
                NSRect(x: 0, y: 0, width: size.width, height: fillTop).fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            NSColor.black.setStroke()
            outline.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = String(localized: "Plouf")
        return image
    }
}
