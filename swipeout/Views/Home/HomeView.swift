//
//  HomeView.swift
//  swipeout (SwipeClean)
//
//  Dashboard: lifetime stats summary, limited-access notice, and the
//  entry point into a swipe session via the mode selector.
//

import SwiftUI

struct HomeView: View {
    @Environment(LibraryViewModel.self) private var library
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @State private var path = NavigationPath()
    @State private var showTour = false
    @State private var tourIndex = 0

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 22) {
                Spacer(minLength: 0)

                if library.access == .limited {
                    LimitedAccessBanner()
                }

                StatsSummaryCard(stats: library.lifetimeStats)

                Button {
                    startCleaning()
                } label: {
                    Label("Start Cleaning", systemImage: "hand.draw.fill")
                }
                .buttonStyle(.glass(tint: .accentColor, prominent: true))
                .accessibilityIdentifier("startCleaningButton")
                .tourTarget("startCleaningButton")

                Button {
                    path.append(Route.dateRangePicker)
                } label: {
                    Label("Browse by Date", systemImage: "calendar")
                }
                .buttonStyle(.glass())
                .accessibilityIdentifier("browseByDateButton")
                .tourTarget("browseByDateButton")

                if library.pendingCount > 0 {
                    Button {
                        path.append(Route.pendingDeletions)
                    } label: {
                        Label("Review \(library.pendingCount) Marked for Deletion",
                              systemImage: "trash")
                    }
                    .buttonStyle(.glass(tint: .red))
                    .accessibilityIdentifier("pendingDeletionsButton")
                    .tourTarget("pendingDeletionsButton")
                }

                NavigationLink(value: Route.stats) {
                    Label("View Stats", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.glass())
                .accessibilityIdentifier("viewStatsButton")
                .tourTarget("viewStatsButton")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appBackground()
            .navigationTitle("SwipeClean")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isDarkMode.toggle()
                    } label: {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max")
                    }
                    .accessibilityIdentifier("darkModeToggle")
                    .accessibilityLabel(isDarkMode ? "Switch to light mode" : "Switch to dark mode")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .modeSelector(let purpose):
                    ModeSelectorView(path: $path, purpose: purpose)
                case .swipe(let mode):
                    SwipeContainerView(mode: mode, path: $path)
                case .dateRangePicker:
                    DateRangePickerView(path: $path)
                case .pendingDeletions:
                    PendingDeletionsView(path: $path)
                case .stats:
                    StatsView()
                case .settings:
                    SettingsView(path: $path)
                }
            }
            .onAppear {
                library.refreshStats()
                library.refreshReviewState()
                if library.albums.isEmpty { library.loadAlbums() }
                if !hasSeenTour { startTour() }
            }
        }
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if showTour {
                    TourOverlay(steps: TourStep.home,
                                anchors: anchors,
                                proxy: proxy,
                                index: $tourIndex) {
                        hasSeenTour = true
                        showTour = false
                        tourIndex = 0
                    }
                }
            }
        }
    }

    /// Starts the intro tour from the beginning, once the layout has settled.
    private func startTour() {
        tourIndex = 0
        // Let the first layout pass complete so target frames are measured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showTour = true
        }
    }

    /// First run → show the mode selector. Afterwards → go straight to the
    /// previously chosen mode (changeable from Settings).
    private func startCleaning() {
        if let mode = library.selectedMode {
            path.append(Route.swipe(mode: mode))
        } else {
            path.append(Route.modeSelector(purpose: .firstTime))
        }
    }
}

/// Navigation routes for the app's main stack.
enum Route: Hashable {
    case modeSelector(purpose: ModeSelectorPurpose)
    case swipe(mode: BrowseMode)
    case dateRangePicker
    case pendingDeletions
    case stats
    case settings
}

/// Why the mode selector is being shown.
enum ModeSelectorPurpose: Hashable {
    /// First run: choosing the mode starts a session immediately.
    case firstTime
    /// Invoked from Settings: choosing the mode just saves it and pops back.
    case changeFromSettings
}

struct StatsSummaryCard: View {
    let stats: LifetimeStats

    var body: some View {
        VStack(spacing: 12) {
            Text("Lifetime Cleanup")
                .font(.subheadline)
                .foregroundStyle(Color.appSubtext)
            HStack(spacing: 32) {
                metric(value: "\(stats.totalPhotosDeleted)", label: "Photos")
                metric(value: StorageFormat.gigabytes(stats.totalBytesFreed), label: "Freed")
            }
        }
        .foregroundStyle(Color.appText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.appButton.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(Color.appSubtext)
        }
    }
}

struct LimitedAccessBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited Photos Access").font(.subheadline.bold())
                Text("Only the photos you selected are available. You can allow more in Settings.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Manage in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("limitedAccessBanner")
    }
}

#Preview {
    HomeView().environment(LibraryViewModel())
}
