//
//  AppStyle.swift
//  swipeout (SwipeClean)
//
//  Shared visual identity: the full-bleed background image (different art for
//  light vs. dark mode) with a readability scrim, and a translucent
//  "liquid glass" button style built on the system material blur.
//

import SwiftUI

// MARK: - Background

/// Full-screen background image that adapts to light/dark mode, with a subtle
/// scrim so foreground text and glass controls stay legible over any photo.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var imageName: String {
        colorScheme == .dark ? "BackgroundDark" : "BackgroundLight"
    }

    var body: some View {
        GeometryReader { geo in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .overlay {
            // Darken slightly in dark mode, lift legibility in light mode.
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.45)]
                    : [.black.opacity(0.10), .clear, .black.opacity(0.20)],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Places the adaptive background image behind this view.
    func appBackground() -> some View {
        background(AppBackground())
    }
}

// MARK: - Liquid glass button style

/// A semi-transparent frosted-glass button: system material blur, a soft
/// hairline border, and a gentle press animation. Works on any background.
struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontDesign(.serif)
            .foregroundStyle(prominent ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    if let tint {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(tint.opacity(prominent ? 0.55 : 0.18))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    /// Frosted-glass button. `prominent` gives it a stronger tinted fill.
    static func glass(tint: Color? = nil, prominent: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, prominent: prominent)
    }
}
