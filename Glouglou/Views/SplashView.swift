import SwiftUI

/// Petite éclaboussure de gouttes qui jaillissent quand l'objectif du jour est atteint.
/// Se joue une fois à chaque changement de `trigger`.
struct SplashView: View {
    let trigger: Int

    /// Une goutte de l'éclaboussure : direction, distance et taille tirées au hasard.
    private struct Droplet: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let delay: Double
    }

    @State private var droplets: [Droplet] = []
    @State private var burst = false

    var body: some View {
        ZStack {
            // Onde qui s'élargit.
            Circle()
                .strokeBorder(Theme.waterLight.opacity(burst ? 0 : 0.8), lineWidth: 3)
                .frame(width: burst ? 220 : 20, height: burst ? 220 : 20)

            ForEach(droplets) { drop in
                Image(systemName: "drop.fill")
                    .font(.system(size: drop.size))
                    .foregroundStyle(Theme.waterGradient)
                    .rotationEffect(.degrees(drop.angle + 90))
                    .offset(x: burst ? cos(drop.angle * .pi / 180) * drop.distance : 0,
                            y: burst ? sin(drop.angle * .pi / 180) * drop.distance + 30 : 0)
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 0.6 : 1)
                    .animation(.easeOut(duration: 1.1).delay(drop.delay), value: burst)
            }
        }
        .animation(.easeOut(duration: 0.9), value: burst)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in play() }
    }

    private func play() {
        burst = false
        droplets = (0..<16).map { index in
            Droplet(angle: Double(index) * 360 / 16 + Double.random(in: -10...10) - 90,
                    distance: .random(in: 70...130),
                    size: .random(in: 10...18),
                    delay: .random(in: 0...0.08))
        }
        // On laisse SwiftUI placer les gouttes au centre avant de les faire jaillir.
        DispatchQueue.main.async {
            burst = true
        }
        // Nettoyage une fois l'animation terminée.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            droplets = []
            burst = false
        }
    }
}
