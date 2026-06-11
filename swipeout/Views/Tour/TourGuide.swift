//
//  TourGuide.swift
//  swipeout (SwipeClean)
//
//  A lightweight, self-contained coach-mark / "intro tour" system.
//
//  It dims the whole screen, cuts a spotlight around one button at a time,
//  shows an explanation bubble with a 🔊 speech button (VoiceOver-independent
//  text-to-speech), and lets the user step through every button once. The user
//  dismisses it via "Done" or "Don't show again" — after which it never shows
//  automatically again (persisted in `hasSeenTour`).
//
//  How it works:
//    1. Tag a button with `.tourTarget("someID")` to record its on-screen frame.
//    2. Provide an ordered list of `TourStep`s referencing those IDs.
//    3. Overlay `TourOverlay` via `.overlayPreferenceValue(TourAnchorKey.self)`.
//
//  Toolbar buttons can't be measured through preferences, so their steps use a
//  `fallback` corner instead of a measured anchor.
//

import SwiftUI
import AVFoundation

// MARK: - Step model

/// A corner used to place the spotlight when a button can't be measured
/// (e.g. items living in the navigation bar / toolbar).
enum TourFallbackCorner {
    case topLeading
    case topTrailing
}

/// One stop on the guided tour.
struct TourStep: Identifiable {
    let id: String
    let title: String
    let message: String
    /// Used when the target isn't measurable via preferences (toolbar items).
    var fallback: TourFallbackCorner?

    /// The default tour for the Home screen — walks through every button once.
    static let home: [TourStep] = [
        TourStep(id: "darkModeToggle",
                 title: "Light & Dark Mode",
                 message: "Tap the sun or moon in the top-left corner to switch between light and dark appearance any time.",
                 fallback: .topLeading),
        TourStep(id: "startCleaningButton",
                 title: "Start Cleaning",
                 message: "This is where the magic happens. Tap to start swiping through your photos — swipe left to mark a photo for deletion, swipe right to keep it."),
        TourStep(id: "browseByDateButton",
                 title: "Browse by Date",
                 message: "Want to clean up a specific time period? Zoom through your timeline by year and month and pick a custom start and end. It's a one-off — your usual place is kept."),
        TourStep(id: "pendingDeletionsButton",
                 title: "Marked for Deletion",
                 message: "Photos you mark collect here. Open this folder to review them and permanently delete them when you're ready."),
        TourStep(id: "viewStatsButton",
                 title: "Your Stats",
                 message: "See how many photos you've cleaned up and how much storage you've freed over time."),
        TourStep(id: "settingsButton",
                 title: "Settings",
                 message: "Change your browse mode, manage your review history, toggle dark mode, and review privacy details here.",
                 fallback: .topTrailing)
    ]
}

// MARK: - Anchor collection

/// Collects the frames of all tagged tour targets.
struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as a tour target so the overlay can spotlight it.
    func tourTarget(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// Masks `self` using the inverse of `mask` (i.e. cuts a hole).
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            ZStack {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

// MARK: - Speech

/// Speaks tour explanations aloud on demand (independent of VoiceOver).
@Observable
final class TourSpeaker {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

// MARK: - Overlay

struct TourOverlay: View {
    let steps: [TourStep]
    let anchors: [String: Anchor<CGRect>]
    let proxy: GeometryProxy
    @Binding var index: Int
    /// Called when the tour ends (either "Done" or "Don't show again").
    let onFinish: () -> Void

    @State private var speaker = TourSpeaker()

    /// Steps we can actually point at right now (measured or with a fallback).
    private var visibleSteps: [TourStep] {
        steps.filter { anchors[$0.id] != nil || $0.fallback != nil }
    }

    var body: some View {
        let visible = visibleSteps
        if visible.isEmpty {
            Color.clear.onAppear(perform: onFinish)
        } else {
            let safeIndex = min(max(index, 0), visible.count - 1)
            let step = visible[safeIndex]
            let insets = proxy.safeAreaInsets
            let full = CGSize(width: insets.leading + proxy.size.width + insets.trailing,
                              height: insets.top + proxy.size.height + insets.bottom)
            let spot = toScreen(rect(for: step), insets: insets)

            ZStack(alignment: .topLeading) {
                // Dimmed background with a spotlight hole. Captures all taps so
                // the underlying (highlighted) button can't be triggered mid-tour.
                Color.black.opacity(0.74)
                    .frame(width: full.width, height: full.height)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 14)
                            .frame(width: spot.width + 18, height: spot.height + 18)
                            .position(x: spot.midX, y: spot.midY)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { advance(in: visible, from: safeIndex) }

                // Spotlight ring.
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: spot.width + 18, height: spot.height + 18)
                    .position(x: spot.midX, y: spot.midY)
                    .allowsHitTesting(false)

                callout(step: step, spot: spot, full: full,
                        visible: visible, idx: safeIndex)
            }
            .frame(width: full.width, height: full.height)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.25), value: safeIndex)
            .onChange(of: safeIndex) { _, _ in speaker.stop() }
            .transition(.opacity)
        }
    }

    // MARK: Callout bubble

    @ViewBuilder
    private func callout(step: TourStep, spot: CGRect, full: CGSize,
                         visible: [TourStep], idx: Int) -> some View {
        let placeBelow = spot.midY < full.height * 0.5
        let calloutY = placeBelow
            ? min(spot.maxY + 150, full.height - 150)
            : max(spot.minY - 150, 150)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.title).font(.headline)
                Spacer()
                Button {
                    speaker.speak("\(step.title). \(step.message)")
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                }
                .accessibilityIdentifier("tourSpeakButton")
                .accessibilityLabel("Read aloud")
            }

            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("\(idx + 1) of \(visible.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if idx > 0 {
                    Button("Back") { back(from: idx) }
                        .accessibilityIdentifier("tourBackButton")
                }
                Button(idx == visible.count - 1 ? "Done" : "Next") {
                    advance(in: visible, from: idx)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("tourNextButton")
            }

            Button("Don't show again") { finish() }
                .font(.caption)
                .accessibilityIdentifier("tourDontShowAgainButton")
        }
        .padding()
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8)
        .padding(.horizontal, 20)
        .position(x: full.width / 2, y: calloutY)
    }

    // MARK: Navigation

    private func advance(in visible: [TourStep], from idx: Int) {
        speaker.stop()
        if idx >= visible.count - 1 {
            finish()
        } else {
            index = idx + 1
        }
    }

    private func back(from idx: Int) {
        speaker.stop()
        index = max(0, idx - 1)
    }

    private func finish() {
        speaker.stop()
        onFinish()
    }

    // MARK: Geometry

    /// Frame of the step's target in the GeometryReader's (content) space.
    private func rect(for step: TourStep) -> CGRect {
        if let anchor = anchors[step.id] {
            return proxy[anchor]
        }
        // Approximate position for toolbar buttons. In the content coordinate
        // space (origin at the top of the safe area) the navigation-bar buttons
        // sit just below the top edge, roughly centred ~22pt down.
        let size: CGFloat = 40
        let y: CGFloat = 22 - size / 2
        switch step.fallback {
        case .topLeading:
            return CGRect(x: 8, y: y, width: size, height: size)
        case .topTrailing:
            return CGRect(x: proxy.size.width - size - 8, y: y, width: size, height: size)
        case .none:
            return .zero
        }
    }

    /// Converts a content-space rect to the full-screen space used for drawing.
    private func toScreen(_ r: CGRect, insets: EdgeInsets) -> CGRect {
        r.offsetBy(dx: insets.leading, dy: insets.top)
    }
}
