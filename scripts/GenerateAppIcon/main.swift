// Génère l'icône de l'app (toutes les tailles) dans Assets.xcassets/AppIcon.appiconset.
// Utilisation, depuis la racine du projet :
//   swiftc -o /tmp/appicon scripts/GenerateAppIcon/main.swift Carafe/Icon/DropIconRenderer.swift && /tmp/appicon
import AppKit

let output = "Carafe/Resources/Assets.xcassets/AppIcon.appiconset"

/// Dessine l'icône dans un carré de `side` pixels.
func drawIcon(side: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    // Carré arrondi « squircle » qui occupe toute la surface (forme des icônes macOS récentes).
    let shape = NSBezierPath(roundedRect: rect, xRadius: side * 0.2237, yRadius: side * 0.2237)
    shape.addClip()

    // Fond : dégradé bleu, du bleu ciel en haut au bleu profond en bas (comme le logo du site).
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.435, green: 0.714, blue: 1.000, alpha: 1),   // #6FB6FF
        NSColor(srgbRed: 0.039, green: 0.435, blue: 0.878, alpha: 1),   // #0A6FE0
    ])!
    gradient.draw(in: rect, angle: -90)

    // La goutte de Carafe, blanche, à moitié remplie, sans reflet : simple et net.
    let dropSide = side * 0.60
    let dropRect = NSRect(x: (side - dropSide) / 2, y: (side - dropSide) / 2,
                          width: dropSide, height: dropSide)
    let water = NSColor.white.withAlphaComponent(0.9)
    DropIconRenderer.draw(level: 5,
                          lineColor: .white,
                          waterColor: water,
                          surfaceColor: water,
                          shineColor: .clear,
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
