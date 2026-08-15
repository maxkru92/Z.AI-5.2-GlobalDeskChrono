//
//  ThemeEngine.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Modular multi-theme engine with three institutional-grade visual themes.
//  Provides ThemePalette, view modifiers, and pulsing animation components.
//

import SwiftUI

struct ThemePalette {
    let name: String
    let background: Color
    let surfaceBackground: Color
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accentColor: Color
    let successColor: Color
    let warningColor: Color
    let dangerColor: Color
    let gridLineColor: Color
    let titleFont: Font
    let bodyFont: Font
    let monoFont: Font
    let largeFont: Font
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let shadowRadius: CGFloat

    static let vintage = ThemePalette(
        name: "Vintage Chrono",
        background: Color(red: 0.10, green: 0.08, blue: 0.06),
        surfaceBackground: Color(red: 0.16, green: 0.13, blue: 0.09),
        cardBackground: Color(red: 0.20, green: 0.16, blue: 0.10),
        primaryText: Color(red: 0.85, green: 0.78, blue: 0.60),
        secondaryText: Color(red: 0.55, green: 0.50, blue: 0.38),
        accentColor: Color(red: 0.72, green: 0.55, blue: 0.20),
        successColor: Color(red: 0.40, green: 0.65, blue: 0.35),
        warningColor: Color(red: 0.80, green: 0.65, blue: 0.15),
        dangerColor: Color(red: 0.75, green: 0.25, blue: 0.20),
        gridLineColor: Color(red: 0.25, green: 0.20, blue: 0.12),
        titleFont: .system(.title2, design: .serif).weight(.semibold),
        bodyFont: .system(.body, design: .serif),
        monoFont: .system(.body, design: .monospaced),
        largeFont: .system(size: 42, weight: .light, design: .serif),
        cornerRadius: 12, borderWidth: 2, shadowRadius: 10
    )

    static let modern = ThemePalette(
        name: "Modern Minimalist",
        background: Color(red: 0.06, green: 0.06, blue: 0.08),
        surfaceBackground: Color(red: 0.10, green: 0.10, blue: 0.12),
        cardBackground: Color(red: 0.12, green: 0.12, blue: 0.15),
        primaryText: Color.white,
        secondaryText: Color(red: 0.60, green: 0.60, blue: 0.65),
        accentColor: Color(red: 0.20, green: 0.60, blue: 1.0),
        successColor: Color(red: 0.20, green: 0.80, blue: 0.40),
        warningColor: Color(red: 0.95, green: 0.70, blue: 0.15),
        dangerColor: Color(red: 0.90, green: 0.25, blue: 0.25),
        gridLineColor: Color(red: 0.18, green: 0.18, blue: 0.22),
        titleFont: .system(.title2, design: .default).weight(.bold),
        bodyFont: .system(.body, design: .default),
        monoFont: .system(.body, design: .monospaced),
        largeFont: .system(size: 42, weight: .medium, design: .default),
        cornerRadius: 16, borderWidth: 1, shadowRadius: 4
    )

    static let digital = ThemePalette(
        name: "Digital Matrix",
        background: Color(red: 0.01, green: 0.02, blue: 0.01),
        surfaceBackground: Color(red: 0.03, green: 0.05, blue: 0.03),
        cardBackground: Color(red: 0.04, green: 0.07, blue: 0.04),
        primaryText: Color(red: 0.0, green: 0.9, blue: 0.3),
        secondaryText: Color(red: 0.3, green: 0.6, blue: 0.2),
        accentColor: Color(red: 0.0, green: 1.0, blue: 0.5),
        successColor: Color(red: 0.0, green: 0.8, blue: 0.2),
        warningColor: Color(red: 1.0, green: 0.8, blue: 0.0),
        dangerColor: Color(red: 1.0, green: 0.2, blue: 0.1),
        gridLineColor: Color(red: 0.06, green: 0.12, blue: 0.06),
        titleFont: .system(.title2, design: .monospaced).weight(.bold),
        bodyFont: .system(.body, design: .monospaced),
        monoFont: .system(.body, design: .monospaced),
        largeFont: .system(size: 42, weight: .regular, design: .monospaced),
        cornerRadius: 4, borderWidth: 1, shadowRadius: 0
    )
}

@Observable
final class ThemeManager {
    var current: AppTheme = .modern
    var palette: ThemePalette {
        switch current { case .vintage: return .vintage; case .modern: return .modern; case .digital: return .digital }
    }
}

// MARK: - Pulsing Border

struct PulsingBorder: ViewModifier {
    let color: Color
    let isActive: Bool
    let speed: Double
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color, lineWidth: isActive ? 3 : 0)
                .shadow(color: color, radius: isActive ? 20 : 0)
                .scaleEffect(pulseScale)
                .opacity(isActive ? pulseOpacity : 0)
                .animation(isActive ? .easeInOut(duration: speed).repeatForever(autoreverses: true) : .default, value: isActive)
        )
        .onChange(of: isActive) { _, active in
            if active { pulseScale = 1.05; pulseOpacity = 1.0 } else { pulseScale = 1.0; pulseOpacity = 0.0 }
        }
        .onAppear { if isActive { pulseScale = 1.05; pulseOpacity = 1.0 } }
    }
}

extension View {
    func pulsingBorder(color: Color, isActive: Bool, speed: Double = 1.2) -> some View {
        modifier(PulsingBorder(color: color, isActive: isActive, speed: speed))
    }
}

// MARK: - Glow

struct GlowModifier: ViewModifier {
    let color: Color; let radius: CGFloat; let opacity: Double
    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(opacity), radius: radius).shadow(color: color.opacity(opacity * 0.6), radius: radius * 0.5)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 8, opacity: Double = 0.6) -> some View {
        modifier(GlowModifier(color: color, radius: radius, opacity: opacity))
    }
}

// MARK: - Digital Grid Background

struct DigitalGridBackground: View {
    let palette: ThemePalette
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var path = Path(); path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(palette.gridLineColor), lineWidth: 0.5); x += spacing
            }
            var y: CGFloat = 0
            while y < size.height {
                var path = Path(); path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(palette.gridLineColor), lineWidth: 0.5); y += spacing
            }
        }
    }
}

// MARK: - Vintage Texture

struct VintageTextureOverlay: View {
    var body: some View {
        Canvas { context, size in
            let cols = 40, rows = 30
            let cellW = size.width / CGFloat(cols), cellH = size.height / CGFloat(rows)
            for row in 0..<rows {
                for col in 0..<cols {
                    let noise = Double.random(in: 0.0...0.03)
                    let rect = CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH, width: cellW, height: cellH)
                    context.fill(Path(rect), with: .color(Color(red: noise, green: noise * 0.9, blue: noise * 0.6)))
                }
            }
        }
        .opacity(0.5).allowsHitTesting(false)
    }
}

// MARK: - Themed Card

struct ThemedCard: ViewModifier {
    let palette: ThemePalette; let isActive: Bool
    func body(content: Content) -> some View {
        content.background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius)
                .stroke(isActive ? palette.accentColor.opacity(0.6) : palette.gridLineColor, lineWidth: palette.borderWidth))
            .shadow(color: isActive ? palette.accentColor.opacity(0.15) : .clear, radius: palette.shadowRadius)
    }
}

extension View {
    func themedCard(palette: ThemePalette, isActive: Bool = false) -> some View {
        modifier(ThemedCard(palette: palette, isActive: isActive))
    }
}
