//
//  ModeSelectorView.swift
//  swipeout (SwipeClean)
//
//  Lets the user choose Chronological, Random, or Album browsing.
//  Shown automatically on first run; afterwards reachable from Settings to
//  change the saved mode.
//

import SwiftUI

struct ModeSelectorView: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Binding var path: NavigationPath
    var purpose: ModeSelectorPurpose = .firstTime
    @State private var category: BrowseCategory = .chronological

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $category) {
                    ForEach(BrowseCategory.allCases) { cat in
                        Text(cat.title).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("categoryPicker")
            }

            switch category {
            case .chronological:
                Section("Order") {
                    modeRow(.newestFirst)
                    modeRow(.oldestFirst)
                }
            case .random:
                Section {
                    modeRow(.random)
                } footer: {
                    Text("Photos appear in a shuffled order with no repeats during the session.")
                }
            case .album:
                Section("Albums") {
                    if library.albums.isEmpty {
                        Text("No albums found.").foregroundStyle(.secondary)
                    } else {
                        ForEach(library.albums) { album in
                            Button {
                                choose(.album(id: album.id, title: album.title))
                            } label: {
                                HStack {
                                    Label(album.title, systemImage: "rectangle.stack")
                                    Spacer()
                                    Text("\(album.estimatedCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(purpose == .firstTime ? "Choose Mode" : "Change Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeRow(_ mode: BrowseMode) -> some View {
        Button {
            choose(mode)
        } label: {
            Label(mode.title, systemImage: mode.systemImage)
        }
        .accessibilityIdentifier("mode_\(mode.title)")
    }

    /// Persists the chosen mode, then either starts a session (first run) or
    /// returns to Settings.
    private func choose(_ mode: BrowseMode) {
        library.selectMode(mode)
        switch purpose {
        case .firstTime:
            path.append(Route.swipe(mode: mode))
        case .changeFromSettings:
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ModeSelectorView(path: .constant(NavigationPath()))
            .environment(LibraryViewModel())
    }
}
