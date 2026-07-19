//
//  AlbumPickerView.swift
//  swipeout (Library Control)
//
//  A reusable album picker sheet: lists user + smart albums, lets the user
//  create a new album on the spot, and shows a star next to the current
//  "Default" album (the down-swipe target). Tapping an album invokes
//  `onSelect` with the chosen (or newly created) album.
//

import SwiftUI

struct AlbumPickerView: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String?
    /// Called with the chosen (or newly created) album; the sheet dismisses itself.
    let onSelect: (AlbumInfo) -> Void

    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let subtitle {
                    Section {
                        Text(subtitle).foregroundStyle(.secondary)
                    }
                }
                Section("Albums") {
                    if library.albums.isEmpty {
                        Text("No albums found.").foregroundStyle(.secondary)
                    } else {
                        ForEach(library.albums) { album in
                            Button {
                                onSelect(album)
                                dismiss()
                            } label: {
                                HStack {
                                    Label(album.title, systemImage: "rectangle.stack")
                                    Spacer()
                                    if library.defaultAlbum?.id == album.id {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .accessibilityLabel("Default album")
                                    }
                                    Text("\(album.estimatedCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    library.setDefaultAlbum(AlbumRef(id: album.id, title: album.title))
                                } label: {
                                    Label("Set Default", systemImage: "star")
                                }
                                .tint(.yellow)
                            }
                            .accessibilityIdentifier("albumPicker_\(album.title)")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateAlbum = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("createAlbumButton")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Album", isPresented: $showCreateAlbum) {
                TextField("Album name", text: $newAlbumName)
                Button("Create") { createAlbum() }
                Button("Cancel", role: .cancel) { newAlbumName = "" }
            }
            .alert("Couldn't Create Album", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func createAlbum() {
        let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        newAlbumName = ""
        guard !name.isEmpty else { return }
        Task {
            do {
                let album = try await library.createAlbum(named: name)
                onSelect(album)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    AlbumPickerView(title: "Move to Album", subtitle: nil) { _ in }
        .environment(LibraryViewModel())
}
