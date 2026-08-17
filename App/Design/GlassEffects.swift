import SwiftUI

// MARK: - Centralized Colorless Liquid Glass system (ported from SiteAgent)

// Native glass is gated while the iOS 26 runtime issue is isolated. The fallback
// keeps the same silhouettes without blocking the main touch/render pipeline.
private let nativeLiquidGlassEnabled = true

enum GlassRole: Sendable {
    case hero
    case card
    case button
    case capsule
    case icon
    case badge
    case tabBar
    case toolbarButton
    case listRow
    case composer
    case composerField

    var cornerRadius: CGFloat {
        switch self {
        case .hero: return 24
        case .card, .listRow: return 18
        case .button: return 16
        case .composer: return 30
        case .composerField: return 20
        case .capsule, .badge: return 999
        case .icon, .toolbarButton: return 14
        case .tabBar: return 30
        }
    }

    var isInteractive: Bool {
        switch self {
        case .button, .capsule, .icon, .badge, .toolbarButton, .tabBar, .composer, .composerField: return true
        case .hero, .card, .listRow: return false
        }
    }

    /// Preserve a visible optical rim on compact controls while keeping broad
    /// surfaces transparent enough for backdrop detail to read through.
    var materialOpacity: Double {
        switch self {
        case .hero, .card, .listRow: return 0.30
        case .button: return 0.12
        case .composer: return 0.72
        case .composerField: return 0.62
        case .capsule, .icon, .badge, .toolbarButton, .tabBar: return 0.52
        }
    }
}

@available(iOS 26.0, *)
private func nativeGlass(for role: GlassRole) -> Glass {
    // Only the main action role uses the denser regular glass. Navigation
    // controls stay clear so their natural edge light never reads as a border.
    var glass: Glass
    switch role {
    case .button:
        glass = .regular
    default:
        glass = .clear
    }
    if role.isInteractive { glass = glass.interactive() }
    return glass
}

private struct GlassSurfaceModifier: ViewModifier {
    let role: GlassRole
    let cornerRadius: CGFloat?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let radius = cornerRadius ?? role.cornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if nativeLiquidGlassEnabled, #available(iOS 26.0, *), !reduceTransparency {
            // Keep Liquid Glass out of layout measurement. A geometry-locked,
            // colorless backdrop preserves original content size while letting the
            // system render live blur, refraction, edge light and interaction.
            content
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .glassEffect(
                                nativeGlass(for: role),
                                in: .rect(cornerRadius: radius)
                            )
                            .opacity(role.isInteractive ? 1 : role.materialOpacity)
                    }
                }
                .overlay {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.24), .white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(role.materialOpacity * 0.22),
                                    .clear,
                                    .black.opacity(role.materialOpacity * 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.26), .white.opacity(0.05), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.045), radius: 5, y: 3)
        }
    }
}

extension View {
    /// Apple Liquid Glass on iOS 26+. Pre-26 renders an ultra-thin material
    /// with the same light-catching silhouette. This is the single surface
    /// primitive the whole theme routes through.
    func glassSurface(
        _ role: GlassRole = .card,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(GlassSurfaceModifier(role: role, cornerRadius: cornerRadius))
    }
}

// MARK: - Shape-based glass variants

extension View {
    /// Clear glass in an arbitrary insettable shape (capsule, circle, …).
    func fClearGlass<S: InsettableShape>(
        in shape: S,
        interactive: Bool = false,
        showRim: Bool = true,
        useRegularInteractiveGlass: Bool = false
    ) -> some View {
        modifier(ShapeGlassSurfaceModifier(
            shape: shape,
            role: interactive ? (useRegularInteractiveGlass ? .button : .toolbarButton) : .capsule,
            showRim: showRim
        ))
    }

    /// Direct regular Liquid Glass for a primary tap target. Unlike the generic
    /// backdrop helper, this modifier is applied to the actual button label.
    func fPrimaryActionGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(PrimaryActionGlassModifier(shape: shape))
    }

    /// Direct clear Liquid Glass for navigation controls. This has no manually
    /// drawn rim, fill or overlay, so iOS alone controls the glass appearance.
    func fNavigationGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(NavigationGlassModifier(shape: shape))
    }

    /// Card-style glass surface.
    func fGlass(cornerRadius: CGFloat = 18) -> some View {
        glassSurface(.card, cornerRadius: cornerRadius)
    }

    /// Capsule variant of `fGlass`.
    func fGlassCapsule() -> some View {
        modifier(ShapeGlassSurfaceModifier(shape: Capsule(), role: .capsule, showRim: true))
    }
}

private struct PrimaryActionGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if nativeLiquidGlassEnabled, #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
    }
}

private struct NavigationGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if nativeLiquidGlassEnabled, #available(iOS 26.0, *), !reduceTransparency {
            // The control now lives outside ToolbarItem, so the native clear
            // glass can render its real interactive reflection without the
            // toolbar container adding a second white capsule around it.
            content
                .glassEffect(.clear.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(colorScheme == .dark ? 0.14 : 0.22), location: 0.00),
                                .init(color: .white.opacity(colorScheme == .dark ? 0.04 : 0.08), location: 0.40),
                                .init(color: .clear, location: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
                }
        }
    }
}

private struct ShapeGlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let role: GlassRole
    let showRim: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if nativeLiquidGlassEnabled, #available(iOS 26.0, *), !reduceTransparency {
            content
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .glassEffect(nativeGlass(for: role), in: shape)
                            .opacity(role.isInteractive ? 1 : role.materialOpacity)
                    }
                }
                .overlay {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(showRim ? 0.24 : 0), .white.opacity(showRim ? 0.06 : 0), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(role.materialOpacity * 0.20), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(showRim ? 0.26 : 0), .white.opacity(showRim ? 0.05 : 0), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

// MARK: - Glass Container Morphing

/// Morphing container for glass elements on iOS 26+.
struct FGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
                    if nativeLiquidGlassEnabled, #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) { content() }

        } else {
            content()
        }
    }
}

// MARK: - Working Shimmer Effect

extension View {
    func shimmer(
        isActive: Bool = true,
        duration: Double = 1.4,
        intensity: Double = 0.55
    ) -> some View {
        modifier(ShimmerModifier(isActive: isActive, duration: duration, intensity: intensity))
    }
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    let duration: Double
    let intensity: Double

    @State private var phase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive, !reduceMotion {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let bandWidth = width * 0.65
                        LinearGradient(
                            stops: [
                                .init(color: .clear,                    location: 0.0),
                                .init(color: .white.opacity(intensity), location: 0.5),
                                .init(color: .clear,                    location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        .offset(x: phase * (width + bandWidth))
                        .blendMode(.softLight)
                    }
                    .allowsHitTesting(false)
                }
            }
            .mask(content)
            .onAppear {
                guard isActive, !reduceMotion else { return }
                withAnimation(
                    .linear(duration: duration).repeatForever(autoreverses: false)
                ) { phase = 1.0 }
            }
            .onChange(of: isActive) { nowActive in
                if nowActive, !reduceMotion {
                    phase = -1.0
                    withAnimation(
                        .linear(duration: duration).repeatForever(autoreverses: false)
                    ) { phase = 1.0 }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { phase = -1.0 }
                }
            }
    }
}

// MARK: - Unified Liquid Glass sheet presentation

extension View {
    /// Keeps the presenting canvas visible while the system sheet animates in,
    /// matching the glass language used by the language picker.
    func liquidGlassSheet() -> some View {
        presentationBackground(.clear)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.hidden)
    }
}


// MARK: - Borderless milky glass

private struct MilkGlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let role: GlassRole = interactive ? .composerField : .card
        let whiteOpacity = colorScheme == .dark ? 0.12 : 0.34

        if nativeLiquidGlassEnabled, #available(iOS 26.0, *), !reduceTransparency {
            content
                .background {
                    GeometryReader { geometry in
                        Color.white.opacity(whiteOpacity)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .glassEffect(nativeGlass(for: role), in: shape)
                    }
                }
                .clipShape(shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(Color.white.opacity(whiteOpacity), in: shape)
                .clipShape(shape)
        }
    }
}

extension View {
    /// Milky white Liquid Glass without a visible stroke or border.
    func fMilkGlass<S: InsettableShape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(MilkGlassSurfaceModifier(shape: shape, interactive: interactive))
    }
}
