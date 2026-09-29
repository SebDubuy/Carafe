import AppKit

/// Dessine l'icône de Carafe : une goutte d'eau qui se remplit de bleu selon
/// la progression. Contour blanc sur barre sombre, graphite sur barre claire, orange en
/// alerte : l'image n'est donc pas en mode « template » et ses couleurs sont choisies
/// à la main selon l'apparence de la barre.
enum DropIconRenderer {
    /// Nombre de paliers de remplissage (0 = vide, `levels` = plein).
    static let levels = 10

    /// Taille de l'icône en points (hauteur standard d'une icône de barre de menus).
    static let size = NSSize(width: 18, height: 18)

    /// Palier correspondant à une progression entre 0 et 1.
    /// Une goutte entamée n'apparaît jamais vide, une goutte pas tout à fait remplie jamais pleine.
    static func level(for progress: Double) -> Int {
        let clamped = min(max(progress, 0), 1)
        if clamped <= 0 { return 0 }
        if clamped >= 1 { return levels }
        return min(max(Int((clamped * Double(levels)).rounded()), 1), levels - 1)
    }

    /// Cache des images déjà dessinées, une par palier et par apparence.
    private static var cache: [String: NSImage] = [:]

    /// Icône de la barre de menus. `alert` : rien bu depuis longtemps → contour orange
    /// (rappel discret, sans notification).
    static func image(progress: Double, darkMenuBar: Bool, alert: Bool = false) -> NSImage {
        let level = level(for: progress)
        let key = "\(level)-\(darkMenuBar)-\(alert)"
        if let cached = cache[key] { return cached }
        let image = NSImage(size: size, flipped: false) { rect in
            draw(level: level, darkMenuBar: darkMenuBar, alert: alert, in: menuBarRect(in: rect))
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = String(localized: "Carafe")
        cache[key] = image
        return image
    }

    /// Zone de dessin dans la barre de menus : la goutte est un peu réduite (les icônes
    /// système font environ 15 pt de haut sur 18) et légèrement descendue, pour que sa
    /// partie ronde, qui porte le poids visuel, s'aligne sur les icônes voisines.
    private static func menuBarRect(in rect: NSRect) -> NSRect {
        let scale: CGFloat = 0.86
        let side = rect.width * scale
        return NSRect(x: rect.midX - side / 2,
                      y: rect.midY - side / 2 - 0.5,   // y vers le haut : −0,5 pt = plus bas
                      width: side, height: side)
    }

    /// Goutte à moitié pleine en mode « template » (monochrome, adaptée au thème par macOS),
    /// pour l'onglet « Verres » des réglages.
    static let templateDrop: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(level: levels / 2, lineColor: .black,
                 waterColor: NSColor.black.withAlphaComponent(0.45),
                 surfaceColor: NSColor.black.withAlphaComponent(0.25),
                 in: rect.insetBy(dx: 1, dy: 1))
            return true
        }
        image.isTemplate = true
        return image
    }()

    // MARK: - Dessin


    /// Orange de l'état « alerte ».
    private static let alertOrange = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.10, alpha: 1)

    /// Bleu de l'eau (le bleu du système, comme `Theme.water`).
    private static var water: NSColor { .systemBlue }

    /// Dessine la goutte de la barre de menus : eau bleue, contour blanc sur barre
    /// sombre, graphite sur barre claire, orange en alerte.
    static func draw(level: Int, darkMenuBar: Bool, alert: Bool = false, in rect: NSRect) {
        let ink = darkMenuBar ? NSColor.white : NSColor(white: 0.12, alpha: 1)
        draw(level: level,
             lineColor: alert ? alertOrange : ink,
             waterColor: water,
             surfaceColor: water.blended(withFraction: 0.35, of: .white) ?? water,
             shineColor: NSColor.white.withAlphaComponent(0.75),
             in: rect)
    }

    /// Dessine la goutte dans `rect` (coordonnées pensées pour 18 × 18 puis mises à l'échelle).
    static func draw(level: Int, lineColor: NSColor, waterColor: NSColor, surfaceColor: NSColor,
                     shineColor: NSColor = NSColor.white.withAlphaComponent(0.85),
                     in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / size.width, y: rect.height / size.height)

        let lineWidth: CGFloat = 1.3
        let drop = dropPath()

        // Eau : découpée dans la goutte, avec une ligne de surface plus claire.
        if level > 0 {
            let waterY = waterBottom + (waterTop - waterBottom) * CGFloat(level) / CGFloat(levels)
            NSGraphicsContext.saveGraphicsState()
            drop.addClip()
            waterColor.setFill()
            NSRect(x: 0, y: 0, width: size.width, height: waterY).fill()
            if level < levels {
                surfaceColor.setFill()
                NSRect(x: 0, y: waterY - 1.1, width: size.width, height: 1.1).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        // Contour.
        lineColor.setStroke()
        drop.lineWidth = lineWidth
        drop.lineJoinStyle = .round
        drop.stroke()

        // Petit reflet, pour donner du volume.
        let shine = NSBezierPath()
        shine.appendArc(withCenter: NSPoint(x: center.x, y: center.y), radius: radius - 2.4,
                        startAngle: 200, endAngle: 245)
        shine.lineWidth = 1.1
        shine.lineCapStyle = .round
        (level >= 3 ? shineColor : lineColor.withAlphaComponent(0.55)).setStroke()
        shine.stroke()

        context.restoreGState()
    }

    // MARK: - Géométrie de la goutte

    /// Centre et rayon de la partie ronde (le bas de la goutte).
    private static let center = NSPoint(x: 9, y: 6.5)
    private static let radius: CGFloat = 5.4
    /// Pointe de la goutte.
    private static let tip = NSPoint(x: 9, y: 16.9)
    /// Hauteurs de l'eau : vide et pleine.
    private static let waterBottom: CGFloat = 1.1
    private static let waterTop: CGFloat = 16.9

    /// Goutte classique : un cercle en bas, prolongé par deux flancs tangents
    /// qui se rejoignent en pointe.
    private static func dropPath() -> NSBezierPath {
        // Points où les flancs touchent le cercle (tangentes depuis la pointe).
        let distance = tip.y - center.y
        let beta = acos(radius / distance) * 180 / .pi   // angle depuis la verticale
        let leftAngle = 90 + beta
        let rightAngle = 90 - beta
        func point(_ degrees: CGFloat) -> NSPoint {
            let r = degrees * .pi / 180
            return NSPoint(x: center.x + radius * cos(r), y: center.y + radius * sin(r))
        }
        let left = point(leftAngle)
        let right = point(rightAngle)

        // Les points de contrôle restent sur la tangente au cercle : raccord parfaitement lisse,
        // flancs presque droits, juste un peu pleins près de la pointe.
        func along(_ from: NSPoint, _ to: NSPoint, _ t: CGFloat) -> NSPoint {
            NSPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        let fullness: CGFloat = 0.35   // flancs légèrement pleins vers l'extérieur

        let path = NSBezierPath()
        path.move(to: tip)
        let leftCP1 = along(tip, left, 0.35)
        path.curve(to: left,
                   controlPoint1: NSPoint(x: leftCP1.x - fullness, y: leftCP1.y),
                   controlPoint2: along(left, tip, 0.3))
        path.appendArc(withCenter: center, radius: radius,
                       startAngle: leftAngle, endAngle: rightAngle + 360, clockwise: false)
        let rightCP2 = along(tip, right, 0.35)
        path.curve(to: tip,
                   controlPoint1: along(right, tip, 0.3),
                   controlPoint2: NSPoint(x: rightCP2.x + fullness, y: rightCP2.y))
        path.close()
        return path
    }
}
