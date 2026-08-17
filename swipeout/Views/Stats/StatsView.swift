//
//  StatsView.swift
//  swipeout (Library Control)
//
//  Extended stats page: library coverage, cleanup totals, time spent,
//  and efficiency metrics.
//

import SwiftUI

struct StatsView: View {
    @Environment(LibraryViewModel.self) private var library

    /// Total photos/videos in the library (fetched once on appear).
    @State private var libraryTotals: (photos: Int, videos: Int) = (0, 0)

    private var stats: LifetimeStats { library.lifetimeStats }
    private var reviewedCount: Int    { library.reviewedCount }
    private var totalLibrary: Int     { libraryTotals.photos + libraryTotals.videos }
    private var coverageFraction: Double {
        guard totalLibrary > 0 else { return 0 }
        return min(1.0, Double(reviewedCount) / Double(totalLibrary))
    }

    var body: some View {
        List {

            // MARK: - Library Coverage
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Library Sorted")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(percentText(coverageFraction))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.tint)
                    }

                    ProgressView(value: coverageFraction)
                        .tint(.accentColor)

                    HStack {
                        Label("\(reviewedCount) reviewed", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(totalLibrary) total")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    if libraryTotals.photos > 0 || libraryTotals.videos > 0 {
                        HStack(spacing: 16) {
                            typeChip(count: libraryTotals.photos, label: "Photos",
                                     symbol: "photo")
                            typeChip(count: libraryTotals.videos, label: "Videos",
                                     symbol: "video")
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Coverage")
            }

            // MARK: - Cleanup
            Section("Cleanup") {
                statRow(label: "Photos deleted",
                        value: "\(stats.totalPhotosDeleted)",
                        symbol: "trash")
                statRow(label: "Storage freed",
                        value: StorageFormat.gigabytes(stats.totalBytesFreed),
                        symbol: "internaldrive")
                if stats.totalPhotosDeleted > 0 && stats.totalBytesFreed > 0 {
                    let avgMB = Double(stats.totalBytesFreed) / Double(stats.totalPhotosDeleted) / 1_000_000
                    statRow(label: "Avg size per deleted photo",
                            value: String(format: "%.1f MB", avgMB),
                            symbol: "photo.badge.arrow.down")
                }
            }

            // MARK: - Time Spent
            Section("Time Spent") {
                statRow(label: "Total organizing time",
                        value: stats.totalTimeSpentSeconds > 0
                               ? stats.formattedTimeSpent
                               : "—",
                        symbol: "clock")

                if let minsPerGB = stats.minutesPerGigabyte {
                    statRow(label: "Efficiency",
                            value: String(format: "%.1f min / GB saved", minsPerGB),
                            symbol: "bolt")
                }
            }

            // MARK: - Disclaimer
            Section {
                Text("Storage figures are estimates based on each photo's reported file size. Actual space is reclaimed once photos leave \"Recently Deleted\". Library totals include only photos and videos accessible to this app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            library.refreshStats()
            library.refreshReviewState()
            // Fetch library totals on a background task to avoid blocking the main thread
            // for large libraries.
            Task {
                let totals = library.fetchLibraryTotals()
                libraryTotals = totals
            }
        }
    }

    // MARK: Sub-views

    private func statRow(label: String, value: String, symbol: String) -> some View {
        HStack {
            Label(label, systemImage: symbol)
            Spacer()
            Text(value).font(.headline).foregroundStyle(.tint)
        }
        .accessibilityElement(children: .combine)
    }

    private func typeChip(count: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text("\(count) \(label)").foregroundStyle(.secondary)
        }
    }

    private func percentText(_ fraction: Double) -> String {
        let pct = Int((fraction * 100).rounded())
        return "\(pct)%"
    }
}

#Preview {
    NavigationStack { StatsView().environment(LibraryViewModel()) }
}
