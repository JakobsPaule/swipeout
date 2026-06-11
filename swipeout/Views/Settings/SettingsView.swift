//
//  SettingsView.swift
//  swipeout (SwipeClean)
//

import SwiftUI

struct SettingsView: View {
    @Environment(LibraryViewModel.self) private var library
    @State private var showResetConfirm = false

    var body: some View {
        List {
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
    NavigationStack { SettingsView().environment(LibraryViewModel()) }
}
