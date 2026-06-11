//
//  ModeSelectorView.swift
//  swipeout (SwipeClean)
//
//  Lets the user choose Chronological, Random, or Album browsing.
//

import SwiftUI

struct ModeSelectorView: View {
    @Environment(LibraryViewModel.self) private var library
    @Binding var path: NavigationPath
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
                                path.append(Route.swipe(mode: .album(id: album.id, title: album.title)))
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
        .navigationTitle("Choose Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeRow(_ mode: BrowseMode) -> some View {
        Button {
            path.append(Route.swipe(mode: mode))
        } label: {
            Label(mode.title, systemImage: mode.systemImage)
        }
        .accessibilityIdentifier("mode_\(mode.title)")
    }
}

#Preview {
    NavigationStack {
        ModeSelectorView(path: .constant(NavigationPath()))
            .environment(LibraryViewModel())
    }
}
