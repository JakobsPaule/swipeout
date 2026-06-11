//
//  StatsView.swift
//  swipeout (SwipeClean)
//

import SwiftUI

struct StatsView: View {
    @Environment(LibraryViewModel.self) private var library

    var body: some View {
        List {
            Section("Lifetime") {
                statRow(label: "Photos deleted",
                        value: "\(library.lifetimeStats.totalPhotosDeleted)",
                        symbol: "trash")
                statRow(label: "Estimated storage freed",
                        value: StorageFormat.gigabytes(library.lifetimeStats.totalBytesFreed),
                        symbol: "internaldrive")
            }

            Section {
                Text("Storage figures are estimates based on each photo’s file size as reported by iOS. Actual space is reclaimed once photos leave “Recently Deleted”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { library.refreshStats() }
    }

    private func statRow(label: String, value: String, symbol: String) -> some View {
        HStack {
            Label(label, systemImage: symbol)
            Spacer()
            Text(value).font(.headline).foregroundStyle(.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { StatsView().environment(LibraryViewModel()) }
}
