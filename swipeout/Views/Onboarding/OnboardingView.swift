//
//  OnboardingView.swift
//  swipeout (Library Control)
//

import SwiftUI

struct OnboardingView: View {
    @Environment(LibraryViewModel.self) private var library
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Welcome to Library Control")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Quickly review your photos with a swipe and clear out clutter to free up storage.")
                    .font(.body)
                    .foregroundStyle(Color.appSubtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(symbol: "hand.draw", title: "Swipe to decide",
                           detail: "Left to remove, right to keep.")
                FeatureRow(symbol: "checkmark.shield", title: "Safe by design",
                           detail: "Nothing is deleted until you confirm. Removed photos go to iOS “Recently Deleted”.")
                FeatureRow(symbol: "lock.fill", title: "Private",
                           detail: "No analytics, no uploads, no cloud processing. Everything stays on your device.")
            }
            .padding(.horizontal, 28)

            Spacer()

            Button {
                Task {
                    isRequesting = true
                    await library.requestAccess()
                    isRequesting = false
                }
            } label: {
                Text(isRequesting ? "Requesting…" : "Get Started")
            }
            .buttonStyle(.glass(prominent: true))
            .disabled(isRequesting)
            .padding(.horizontal, 28)
            .accessibilityIdentifier("getStartedButton")

            Text("You’ll be asked for permission to access your photos.")
                .font(.footnote)
                .foregroundStyle(Color.appSubtext)
                .padding(.bottom)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Color.appSubtext)
            }
        }
    }
}

#Preview {
    OnboardingView().environment(LibraryViewModel())
}
