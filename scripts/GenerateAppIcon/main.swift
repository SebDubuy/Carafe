// Génère l'icône de l'app (toutes les tailles) dans Assets.xcassets/AppIcon.appiconset.
// Utilisation, depuis la racine du projet :
//   swiftc -o /tmp/appicon scripts/GenerateAppIcon/main.swift Glouglou/Icon/DropIconRenderer.swift && /tmp/appicon
import AppKit

let output = "Glouglou/Resources/Assets.xcassets/AppIcon.appiconset"

/// Dessine l'icône dans un carré de `side` pixels.
func drawIcon(side: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    // Carré arrondi « squircle » qui occupe toute la surface (forme des icônes macOS récentes).
    let shape = NSBezierPath(roundedRect: rect, xRadius: side * 0.2237, yRadius: side * 0.2237)
    shape.addClip()

    // Fond : verre graphite, clair en haut, profond en bas (palette « gris liquid glass »).
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.64, green: 0.67, blue: 0.71, alpha: 1),
        NSColor(srgbRed: 0.36, green: 0.39, blue: 0.43, alpha: 1),
        NSColor(srgbRed: 0.16, green: 0.18, blue: 0.21, alpha: 1),
    ])!
    gradient.draw(in: rect, angle: -90)

    // Léger reflet en haut, effet verre (dégradé qui s'efface vers le milieu).
    let shine = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    shine.draw(in: NSRect(x: 0, y: side * 0.5, width: side, height: side * 0.5), angle: -90)

    // La goutte de Glouglou, blanche, à moitié remplie.
    let dropSide = side * 0.68
    let dropRect = NSRect(x: (side - dropSide) / 2, y: (side - dropSide) / 2 - side * 0.01,
                          width: dropSide, height: dropSide)
    DropIconRenderer.draw(level: 6,
                          lineColor: .white,
                          waterColor: NSColor.white.withAlphaComponent(0.88),
                          surfaceColor: NSColor.white.withAlphaComponent(0.55),
                          shineColor: NSColor(white: 0.25, alpha: 0.45),
                          in: dropRect)
}

func writePNG(pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(side: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let file = "icon_\(size)x\(size)@\(scale)x.png"
        writePNG(pixels: size * scale, to: "\(output)/\(file)")
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": file])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(output)/Contents.json"))
print("Icône générée dans \(output)")
