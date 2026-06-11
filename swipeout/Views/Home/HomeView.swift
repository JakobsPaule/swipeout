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
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    if library.access == .limited {
                        LimitedAccessBanner()
                    }

                    StatsSummaryCard(stats: library.lifetimeStats)

                    Button {
                        path.append(Route.modeSelector)
                    } label: {
                        Label("Start Cleaning", systemImage: "hand.draw.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("startCleaningButton")

                    NavigationLink(value: Route.stats) {
                        Label("View Stats", systemImage: "chart.bar.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("SwipeClean")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .modeSelector:
                    ModeSelectorView(path: $path)
                case .swipe(let mode):
                    SwipeContainerView(mode: mode, path: $path)
                case .stats:
                    StatsView()
                case .settings:
                    SettingsView()
                }
            }
            .onAppear {
                library.refreshStats()
                if library.albums.isEmpty { library.loadAlbums() }
            }
        }
    }
}

/// Navigation routes for the app's main stack.
enum Route: Hashable {
    case modeSelector
    case swipe(mode: BrowseMode)
    case stats
    case settings
}

struct StatsSummaryCard: View {
    let stats: LifetimeStats

    var body: some View {
        VStack(spacing: 12) {
            Text("Lifetime Cleanup")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 32) {
                metric(value: "\(stats.totalPhotosDeleted)", label: "Photos")
                metric(value: StorageFormat.gigabytes(stats.totalBytesFreed), label: "Freed")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
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
