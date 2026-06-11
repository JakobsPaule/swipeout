//
//  SettingsView.swift
//  swipeout (SwipeClean)
//

import SwiftUI

struct SettingsView: View {
    @Environment(LibraryViewModel.self) private var library
    @Binding var path: NavigationPath
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showResetConfirm = false
    @State private var showClearHistoryConfirm = false
    @State private var showReviewedWarning = false

    var body: some View {
        List {
            Section("Appearance") {
                Toggle(isOn: $isDarkMode) {
                    Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "sun.max")
                }
                .accessibilityIdentifier("darkModeSettingsToggle")
            }

            Section {
                LabeledContent("Current mode", value: library.selectedMode?.title ?? "Not chosen")
                Button("Change Browse Mode") {
                    path.append(Route.modeSelector(purpose: .changeFromSettings))
                }
                .accessibilityIdentifier("changeModeButton")
            } header: {
                Text("Browse Mode")
            } footer: {
                Text("You chose this on first launch. Change it any time here.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { library.showAlreadyReviewed },
                    set: { newValue in
                        if newValue {
                            // Turning on re-shows photos you've already reviewed.
                            showReviewedWarning = true
                        } else {
                            library.setShowAlreadyReviewed(false)
                        }
                    })) {
                    Label("Show already-reviewed photos", systemImage: "eye")
                }
                .accessibilityIdentifier("showReviewedToggle")

                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Label("Delete Review History", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier("clearHistoryButton")
            } header: {
                Text("Review History")
            } footer: {
                Text("SwipeClean remembers which photos you’ve already reviewed (\(library.reviewedCount)) so it doesn’t show them again. Deleting this history means you’ll be shown the same photos again.")
            }

            Section("Privacy") {
                privacyRow("lock.fill", "On-device only",
                           "All photo review and deletion happens locally on your iPhone.")
                privacyRow("icloud.slash", "No uploads",
                           "SwipeClean never sends your photos or data anywhere.")
                privacyRow("chart.bar.xaxis", "No analytics",
                           "We don’t track you or collect usage data.")
            }

            Section("Photos Access") {
                LabeledContent("Current access", value: accessLabel)
                Button("Manage in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset Lifetime Stats", systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("resetStatsButton")
            } footer: {
                Text("Resets your lifetime counters only. This does not affect any photos.")
            }

            Section {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset lifetime stats?",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset Stats", role: .destructive) { library.resetStats() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your counters only. No photos are deleted or changed.")
        }
        .confirmationDialog("Delete review history?",
                            isPresented: $showClearHistoryConfirm, titleVisibility: .visible) {
            Button("Delete History", role: .destructive) { library.clearReviewHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll be shown the same photos again the next time you start cleaning. No photos are deleted or changed.")
        }
        .confirmationDialog("Show already-reviewed photos?",
                            isPresented: $showReviewedWarning, titleVisibility: .visible) {
            Button("Show Them Again") { library.setShowAlreadyReviewed(true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("New sessions will include photos you’ve already reviewed before.")
        }
    }

    private func privacyRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var accessLabel: String {
        switch library.access {
        case .authorized: return "Full"
        case .limited: return "Limited"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not set"
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    NavigationStack {
        SettingsView(path: .constant(NavigationPath()))
            .environment(LibraryViewModel())
    }
}
