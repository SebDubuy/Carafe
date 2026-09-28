import AppKit

/// Dessine l'icône de la barre de menus : un verre qui se remplit d'eau bleue selon la progression.
/// L'image n'est pas en mode « template » (sinon elle serait monochrome) : le contour
/// est donc coloré à la main selon l'apparence de la barre de menus (claire ou sombre).
enum GlassIconRenderer {
    /// Nombre de paliers de remplissage (0 = vide, `levels` = plein).
    static let levels = 10

    /// Taille de l'icône en points (hauteur standard d'une icône de barre de menus).
    static let size = NSSize(width: 18, height: 18)

    /// Palier correspondant à une progression entre 0 et 1.
    /// Un verre entamé n'apparaît jamais vide, un verre pas tout à fait fini jamais plein.
    static func level(for progress: Double) -> Int {
        let clamped = min(max(progress, 0), 1)
        if clamped <= 0 { return 0 }
        if clamped >= 1 { return levels }
        return min(max(Int((clamped * Double(levels)).rounded()), 1), levels - 1)
    }

    /// Cache des images déjà dessinées, une par palier et par apparence.
    private static var cache: [String: NSImage] = [:]

    static func image(progress: Double, darkMenuBar: Bool) -> NSImage {
        let level = level(for: progress)
        let key = "\(level)-\(darkMenuBar)"
        if let cached = cache[key] { return cached }
        let image = NSImage(size: size, flipped: false) { rect in
            draw(level: level, darkMenuBar: darkMenuBar, in: rect)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = String(localized: "Plouf")
        cache[key] = image
        return image
    }

    /// Verre à moitié plein en mode « template » (monochrome, adapté au thème par macOS),
    /// pour l'onglet « Verres » des réglages.
    static let templateGlass: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            // Marge autour du verre, comme les symboles système, pour qu'il ne touche pas
            // les bords du bouton d'onglet.
            draw(level: levels / 2, lineColor: .black,
                 waterColor: NSColor.black.withAlphaComponent(0.45),
                 surfaceColor: NSColor.black.withAlphaComponent(0.25),
                 in: rect.insetBy(dx: 3, dy: 3))
            return true
        }
        image.isTemplate = true
        return image
    }()

    // MARK: - Dessin

    /// Eau bleue de l'icône en couleur.
    private static let blueWater = NSColor(srgbRed: 0.18, green: 0.56, blue: 1.0, alpha: 1)

    /// Dessine le verre en couleur (eau bleue, contour selon la barre de menus).
    static func draw(level: Int, darkMenuBar: Bool, in rect: NSRect) {
        draw(level: level,
             lineColor: darkMenuBar ? .white : NSColor(white: 0.12, alpha: 1),
             waterColor: blueWater,
             surfaceColor: blueWater.blended(withFraction: 0.35, of: .white) ?? blueWater,
             in: rect)
    }

    /// Dessine le verre dans `rect` (les coordonnées sont pensées pour 18 × 18 puis mises à l'échelle).
    static func draw(level: Int, lineColor: NSColor, waterColor: NSColor, surfaceColor: NSColor,
                     in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / size.width, y: rect.height / size.height)

        let lineWidth: CGFloat = 1.3

        // Dimensions du verre : un gobelet légèrement évasé, aux flancs bombés et au fond arrondi.
        let rimY: CGFloat = 15.2       // hauteur du rebord
        let rimHalfWidth: CGFloat = 6.2
        let rimHeight: CGFloat = 3.2   // épaisseur de l'ellipse du rebord
        let bottomY: CGFloat = 1.6
        let bottomHalfWidth: CGFloat = 4.4
        let cornerRadius: CGFloat = 2.2
        let centerX = size.width / 2

        let body = bodyPath(centerX: centerX, rimY: rimY, rimHalfWidth: rimHalfWidth,
                            bottomY: bottomY, bottomHalfWidth: bottomHalfWidth,
                            cornerRadius: cornerRadius)

        // Eau : découpée dans le corps du verre, avec une surface ovale pour donner du volume.
        if level > 0 {
            let maxWaterY = rimY - 1.4
            let waterY = bottomY + (maxWaterY - bottomY) * CGFloat(level) / CGFloat(levels)

            NSGraphicsContext.saveGraphicsState()
            body.addClip()
            waterColor.setFill()
            NSRect(x: 0, y: 0, width: size.width, height: waterY).fill()

            // Surface de l'eau : une ellipse un peu plus claire.
            let halfWidth = halfWidthAt(y: waterY, rimY: rimY, rimHalfWidth: rimHalfWidth,
                                        bottomY: bottomY, bottomHalfWidth: bottomHalfWidth)
            let surfaceHeight = rimHeight * 0.75 * (halfWidth / rimHalfWidth)
            let surface = NSBezierPath(ovalIn: NSRect(x: centerX - halfWidth, y: waterY - surfaceHeight / 2,
                                                     width: halfWidth * 2, height: surfaceHeight))
            surfaceColor.setFill()
            surface.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // Contour du verre.
        lineColor.setStroke()
        body.lineWidth = lineWidth
        body.lineJoinStyle = .round
        body.stroke()

        // Rebord ovale.
        let rim = NSBezierPath(ovalIn: NSRect(x: centerX - rimHalfWidth, y: rimY - rimHeight / 2,
                                             width: rimHalfWidth * 2, height: rimHeight))
        rim.lineWidth = lineWidth * 0.85
        rim.stroke()

        context.restoreGState()
    }

    /// Corps du verre : flancs légèrement bombés et coins du fond arrondis, ouvert en haut
    /// (le haut est fermé par le rebord ovale, mais le chemin est fermé pour servir de masque).
    private static func bodyPath(centerX: CGFloat, rimY: CGFloat, rimHalfWidth: CGFloat,
                                 bottomY: CGFloat, bottomHalfWidth: CGFloat,
                                 cornerRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let topLeft = NSPoint(x: centerX - rimHalfWidth, y: rimY)
        let topRight = NSPoint(x: centerX + rimHalfWidth, y: rimY)
        let bottomLeft = NSPoint(x: centerX - bottomHalfWidth, y: bottomY)
        let bottomRight = NSPoint(x: centerX + bottomHalfWidth, y: bottomY)
        let bulge: CGFloat = 0.5   // bombé des flancs vers l'extérieur

        path.move(to: topLeft)
        // Flanc gauche jusqu'au début de l'arrondi du fond.
        let leftCornerStart = NSPoint(x: bottomLeft.x - 0.25, y: bottomY + cornerRadius)
        path.curve(to: leftCornerStart,
                   controlPoint1: NSPoint(x: topLeft.x + 0.1, y: rimY - 4.5),
                   controlPoint2: NSPoint(x: leftCornerStart.x - bulge, y: leftCornerStart.y + 2.5))
        // Coin inférieur gauche arrondi.
        path.curve(to: NSPoint(x: bottomLeft.x + cornerRadius, y: bottomY),
                   controlPoint1: NSPoint(x: bottomLeft.x, y: bottomY + cornerRadius * 0.3),
                   controlPoint2: NSPoint(x: bottomLeft.x + cornerRadius * 0.3, y: bottomY))
        path.line(to: NSPoint(x: bottomRight.x - cornerRadius, y: bottomY))
        // Coin inférieur droit arrondi.
        let rightCornerEnd = NSPoint(x: bottomRight.x + 0.25, y: bottomY + cornerRadius)
        path.curve(to: rightCornerEnd,
                   controlPoint1: NSPoint(x: bottomRight.x - cornerRadius * 0.3, y: bottomY),
                   controlPoint2: NSPoint(x: bottomRight.x, y: bottomY + cornerRadius * 0.3))
        // Flanc droit jusqu'au rebord.
        path.curve(to: topRight,
                   controlPoint1: NSPoint(x: rightCornerEnd.x + bulge, y: rightCornerEnd.y + 2.5),
                   controlPoint2: NSPoint(x: topRight.x - 0.1, y: rimY - 4.5))
        path.close()
        return path
    }

    /// Demi-largeur approximative du verre à la hauteur `y` (interpolation linéaire).
    private static func halfWidthAt(y: CGFloat, rimY: CGFloat, rimHalfWidth: CGFloat,
                                    bottomY: CGFloat, bottomHalfWidth: CGFloat) -> CGFloat {
        let t = max(0, min(1, (y - bottomY) / (rimY - bottomY)))
        return bottomHalfWidth + (rimHalfWidth - bottomHalfWidth) * t - 0.6
    }
}
