import SwiftUI

/// Technical canvas grid: drawn once with Canvas.
struct GridTexture: View {
    var spacing: CGFloat = 40
    var color: Color = .white.opacity(0.05)

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            ctx.stroke(path, with: .color(color), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// Ambient page canvas shared by the three main interfaces.
/// The canvas intentionally stays uniform behind headers: no gradient bloom or
/// material panel is applied here, so titles never acquire a rectangular halo.
struct ForgeBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            GridTexture(
                spacing: 40,
                color: Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}
