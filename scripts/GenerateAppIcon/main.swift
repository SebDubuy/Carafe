// Génère l'icône de l'app (toutes les tailles) dans Assets.xcassets/AppIcon.appiconset :
// une goutte d'eau brillante (dégradé bleu-lavande → cyan, reflets, halo) sur fond clair.
// Utilisation, depuis la racine du projet :
//   swiftc -o /tmp/appicon scripts/GenerateAppIcon/main.swift && /tmp/appicon [dossier-du-site]
// Avec un dossier en argument, exporte aussi drop.png et app-icon.png pour le site.
import AppKit

let output = "Carafe/Resources/Assets.xcassets/AppIcon.appiconset"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// MARK: - Forme de la goutte

/// Goutte dans le carré `rect` (y vers le haut), tracée d'une seule courbe lisse :
///   x = sin(t) · sin(t/2)^m,  y = cos(t),  t de 0 à 2π
/// La pointe est en haut ; un exposant `m` inférieur à 1 l'arrondit légèrement.
/// La forme est ensuite mise à l'échelle : hauteur 78 % du carré, largeur ≈ 0,74 × hauteur.
func dropPath(in rect: NSRect, m: Double = 0.78) -> NSBezierPath {
    let steps = 360
    var raw: [(Double, Double)] = []
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        raw.append((sin(t) * pow(sin(t / 2), m), cos(t)))
    }
    let maxX = raw.map { abs($0.0) }.max() ?? 1
    let height = Double(rect.height) * 0.78
    let width = height * 0.74
    let cx = Double(rect.midX), cy = Double(rect.midY)
    let path = NSBezierPath()
    for (i, p) in raw.enumerated() {
        let point = NSPoint(x: cx + p.0 / maxX * width / 2, y: cy + p.1 * height / 2)
        i == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    return path
}

// MARK: - Goutte brillante

/// Dessine la goutte brillante dans `rect` (carré).
func drawGlossyDrop(in rect: NSRect, glow: Bool = true) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let s = rect.width
    let drop = dropPath(in: rect)

    // 1. Halo bleu doux sous la goutte.
    if glow {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = rgb(0x4DA6FF, 0.55)
        shadow.shadowBlurRadius = s * 0.10
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.05)
        shadow.set()
        rgb(0x6AA8F4).setFill()
        drop.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.saveGraphicsState()
    drop.addClip()
    let bounds = drop.bounds

    // 2. Fond : bleu-lavande en haut, bleu clair en bas.
    NSGradient(colors: [rgb(0xB9C4F4), rgb(0x86A6F1), rgb(0x60A4F3)],
               atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
        .draw(in: bounds, angle: -90)

    // 3. Lueur cyan dans la partie basse.
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let cyan = CGGradient(colorsSpace: space,
                          colors: [rgb(0x8ADDF8, 0.95).cgColor, rgb(0x8ADDF8, 0).cgColor] as CFArray,
                          locations: [0, 1])!
    let glowCenter = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.30)
    ctx.drawRadialGradient(cyan, startCenter: glowCenter, startRadius: 0,
                           endCenter: glowCenter, endRadius: bounds.width * 0.55, options: [])

    // 4. Reflet intérieur : une goutte plus petite, décalée à droite, qui s'éclaircit vers le haut.
    let inner = dropPath(in: NSRect(x: rect.minX + s * 0.14, y: rect.minY + s * 0.13, width: s * 0.80, height: s * 0.80))
    NSGraphicsContext.saveGraphicsState()
    inner.addClip()
    NSGradient(colors: [rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0.08), rgb(0xFFFFFF, 0)],
               atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
        .draw(in: inner.bounds, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 5. Bord légèrement plus soutenu (effet de volume).
    let rim = CGGradient(colorsSpace: space,
                         colors: [rgb(0x5B82EC, 0).cgColor, rgb(0x5B82EC, 0.55).cgColor] as CFArray,
                         locations: [0.72, 1])!
    let rimCenter = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.42)
    ctx.drawRadialGradient(rim, startCenter: rimCenter, startRadius: 0,
                           endCenter: rimCenter, endRadius: bounds.height * 0.62, options: [])

    // 6. Petit éclat près de la pointe.
    let spark = NSBezierPath(ovalIn: NSRect(x: bounds.midX - s * 0.02, y: bounds.maxY - s * 0.20,
                                            width: s * 0.04, height: s * 0.10))
    rgb(0xFFFFFF, 0.28).setFill()
    spark.fill()

    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Icône de l'app

/// Icône complète : carré arrondi très clair, la goutte brillante au centre.
func drawIcon(side: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    let shape = NSBezierPath(roundedRect: rect, xRadius: side * 0.2237, yRadius: side * 0.2237)
    shape.addClip()
    NSGradient(colors: [rgb(0xFFFFFF), rgb(0xEEF3FB)])!.draw(in: rect, angle: -90)
    let dropSide = side * 1.0
    drawGlossyDrop(in: NSRect(x: (side - dropSide) / 2, y: (side - dropSide) / 2 + side * 0.03,
                              width: dropSide, height: dropSide))
}

func writePNG(pixels: Int, to path: String, draw: (CGFloat) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let file = "icon_\(size)x\(size)@\(scale)x.png"
        writePNG(pixels: size * scale, to: "\(output)/\(file)", draw: drawIcon)
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": file])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(output)/Contents.json"))
print("Icône générée dans \(output)")

// Images pour le site (facultatif).
if CommandLine.arguments.count > 1 {
    let dir = CommandLine.arguments[1]
    writePNG(pixels: 256, to: "\(dir)/drop.png") { side in
        drawGlossyDrop(in: NSRect(x: 0, y: side * 0.04, width: side, height: side))
    }
    writePNG(pixels: 128, to: "\(dir)/app-icon.png", draw: drawIcon)
    print("Images du site dans \(dir)")
}
