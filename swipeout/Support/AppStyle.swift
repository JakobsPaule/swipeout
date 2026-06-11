//
//  AppStyle.swift
//  swipeout (SwipeClean)
//
//  Shared visual identity: the full-bleed background image (different art for
//  light vs. dark mode) with a readability scrim, a consistent legible text
//  palette, and a translucent "liquid glass" button style.
//

import SwiftUI

// MARK: - Readable text palette
//
// The app draws over colourful photo backgrounds in both light and dark mode,
// so the system `.primary` / `.secondary` colours (which flip to black in light
// mode) are unreliable. We standardise on a light text palette layered over a
// darkening scrim, which stays legible over any background in either mode.

extension Color {
    /// Primary foreground for text/icons over the app background.
    static let appText = Color.white
    /// Secondary foreground — still clearly readable (not the faint system grey).
    static let appSubtext = Color.white.opacity(0.82)
    /// A neutral dark-grey surface used for prominent buttons.
    static let appButton = Color(red: 0.16, green: 0.16, blue: 0.18)
}

// MARK: - Background

/// Full-screen background image that adapts to light/dark mode, with a scrim
/// strong enough that the light text palette stays legible over any photo.
struct AppBackground: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    private var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    private var imageName: String {
        isDarkMode ? "BackgroundDark" : "BackgroundLight"
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
            // Darkens the photo so light foreground text reads in both modes.
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.45), .black.opacity(0.28), .black.opacity(0.55)]
                    : [.black.opacity(0.40), .black.opacity(0.28), .black.opacity(0.52)],
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

    /// Renders this content for legibility over the (always darkened) app
    /// background: light text/controls and a light navigation-bar title,
    /// regardless of the user's chosen light/dark appearance.
    func legibleOverBackground() -> some View {
        self
            .environment(\.colorScheme, .dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Liquid glass button style

/// A semi-transparent frosted-glass button: system material blur, a soft
/// hairline border, and a gentle press animation. Works on any background.
/// `prominent` gives it a solid dark-grey fill with white text.
struct GlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontDesign(.serif)
            .foregroundStyle(Color.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(fillColor)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.30), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    /// Prominent buttons get a solid dark-grey fill in both modes; otherwise a
    /// faint tinted wash (or just the frosted material).
    private var fillColor: Color {
        if prominent { return Color.appButton.opacity(0.92) }
        if let tint { return tint.opacity(0.22) }
        return Color.white.opacity(0.06)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    /// Frosted-glass button. `prominent` gives it a solid dark-grey fill.
    static func glass(tint: Color? = nil, prominent: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint, prominent: prominent)
    }
}
