//
//  SwipeContainerView.swift
//  swipeout (Library Control)
//
//  Hosts a swipe session: progress, the photo card, action buttons,
//  undo, and the entry to "Review deletions".
//

import SwiftUI

struct SwipeContainerView: View {
    let mode: BrowseMode
    @Binding var path: NavigationPath

    @Environment(LibraryViewModel.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: SessionHolder

    init(mode: BrowseMode, path: Binding<NavigationPath>) {
        self.mode = mode
        self._path = path
        // Session is built lazily in onAppear via the holder.
        self._session = State(wrappedValue: SessionHolder())
    }

    var body: some View {
        VStack(spacing: 16) {
            if let vm = session.session {
                content(vm)
            } else {
                ProgressView("Loading photos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Pause") {
                    // Persist elapsed time before navigating away.
                    if let vm = session.session { library.recordSessionTime(from: vm) }
                    // Progress is already persisted (reviewed photos are skipped
                    // next time), so just return home; resume picks up where we
                    // left off.
                    library.refreshReviewState()
                    path = NavigationPath()
                }
                .accessibilityIdentifier("pauseSessionButton")
            }
            if let vm = session.session {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(Route.favorites)
                    } label: {
                        Label("\(vm.favoriteCount)", systemImage: "star.fill")
                    }
                    .accessibilityIdentifier("viewFavoritesButton")
                }
            }
            if let vm = session.session {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentReview(vm)
                    } label: {
                        Label("\(vm.deletionCount)", systemImage: "trash")
                    }
                    .accessibilityIdentifier("reviewDeletionsButton")
                }
            }
            if let vm = session.session, vm.currentItem != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMovePicker = true
                    } label: {
                        Label("Move to Album", systemImage: "folder")
                    }
                    .accessibilityIdentifier("moveToAlbumButton")
                }
            }
        }
        .sheet(isPresented: $showReview) {
            if let vm = session.session {
                ReviewDeletionsView(session: vm)
                    .environment(library)
            }
        }
        .sheet(isPresented: $showMovePicker) {
            if let vm = session.session {
                AlbumPickerView(title: "Move to Album", subtitle: nil) { album in
                    Task {
                        await vm.moveCurrentToAlbum(albumID: album.id, albumTitle: album.title)
                        vm.prefetchAround(currentIndex: vm.currentIndex)
                    }
                }
                .environment(library)
            }
        }
        .sheet(isPresented: $showDefaultAlbumPicker) {
            if let vm = session.session {
                AlbumPickerView(title: "Choose Default Album",
                                subtitle: "Swiping down moves a photo straight into this album.") { album in
                    library.setDefaultAlbum(AlbumRef(id: album.id, title: album.title))
                    Task {
                        await vm.moveCurrentToAlbum(albumID: album.id, albumTitle: album.title)
                        vm.prefetchAround(currentIndex: vm.currentIndex)
                    }
                }
                .environment(library)
            }
        }
        .alert("Couldn't Move Photo", isPresented: Binding(
            get: { session.session?.errorMessage != nil },
            set: { if !$0 { session.session?.errorMessage = nil } }
        )) {
            Button("OK") { session.session?.errorMessage = nil }
        } message: {
            Text(session.session?.errorMessage ?? "")
        }
        .onAppear {
            if session.session == nil {
                session.session = library.makeSession(for: mode)
            }
            session.session?.startTimer()
        }
        .onDisappear {
            if let vm = session.session {
                library.recordSessionTime(from: vm)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                session.session?.startTimer()
            case .inactive, .background:
                // Pause the timer; time will be drained on onDisappear.
                session.session?.pauseTimer()
            @unknown default:
                break
            }
        }
    }

    @State private var showReview = false
    @State private var showMovePicker = false
    @State private var showDefaultAlbumPicker = false

    @ViewBuilder
    private func content(_ vm: SwipeSessionViewModel) -> some View {
        if vm.totalCount == 0 {
            if vm.allAlreadyReviewed {
                ContentUnavailableView("All Caught Up", systemImage: "checkmark.circle",
                                       description: Text("All photos have been viewed already. Activate Re-Review in settings if you want to see reviewed photos as well."))
            } else {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle",
                                       description: Text("There are no photos to review in this selection."))
            }
        } else if vm.isFinished {
            SessionFinishedView(vm: vm,
                               showReview: { presentReview(vm) },
                               showFavorites: { path.append(Route.favorites) })
        } else {
            // Progress
            VStack(spacing: 6) {
                ProgressView(value: Double(vm.displayPosition), total: Double(vm.totalCount))
                Text("\(vm.displayPosition) / \(vm.totalCount)")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("progressLabel")
            }
            .padding(.horizontal)

            // Card
            if let item = vm.currentItem {
                PhotoCardView(item: item, session: vm, defaultAlbum: library.defaultAlbum) { decision in
                    switch decision {
                    case .delete: vm.markCurrentForDeletion()
                    case .keep: vm.keepCurrent()
                    case .favorite: vm.favoriteCurrent()
                    case .moveToAlbum(let albumID, let albumTitle):
                        Task {
                            await vm.moveCurrentToAlbum(albumID: albumID, albumTitle: albumTitle)
                            vm.prefetchAround(currentIndex: vm.currentIndex)
                        }
                        return
                    }
                    vm.prefetchAround(currentIndex: vm.currentIndex)
                } onMissingDefaultAlbum: {
                    showDefaultAlbumPicker = true
                }
                .padding(.horizontal)
                .id(item.id)
            }

            // Buttons
            HStack(spacing: 24) {
                actionButton("Delete", "xmark", .red, id: "deleteButton") {
                    vm.markCurrentForDeletion()
                    vm.prefetchAround(currentIndex: vm.currentIndex)
                }
                actionButton("Undo", "arrow.uturn.backward", .gray, id: "undoButton") {
                    vm.undo()
                }
                .disabled(!vm.canUndo)
                actionButton("Favorite", "star.fill", .yellow, id: "favoriteButton") {
                    vm.favoriteCurrent()
                    vm.prefetchAround(currentIndex: vm.currentIndex)
                }
                actionButton("Keep", "checkmark", .green, id: "keepButton") {
                    vm.keepCurrent()
                    vm.prefetchAround(currentIndex: vm.currentIndex)
                }
            }
            .padding(.bottom)
        }
    }

    private func actionButton(_ title: String, _ symbol: String, _ color: Color,
                              id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.15), in: Circle())
                    .foregroundStyle(color)
                Text(title).font(.caption)
            }
        }
        .accessibilityIdentifier(id)
    }

    private func presentReview(_ vm: SwipeSessionViewModel) {
        showReview = true
    }
}

/// Holds the session so it survives view re-creation during navigation.
/// Not @MainActor so it can be initialised from the nonisolated View.init;
/// all access happens on the main actor via SwiftUI body / onAppear.
@Observable
final class SessionHolder {
    var session: SwipeSessionViewModel?
}

struct SessionFinishedView: View {
    var vm: SwipeSessionViewModel
    let showReview: () -> Void
    let showFavorites: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("All done!", systemImage: "checkmark.circle.fill")
        } description: {
            Text(summary)
        } actions: {
            if vm.deletionCount > 0 {
                Button("Review Deletions", action: showReview)
                    .buttonStyle(.borderedProminent)
            }
            if vm.favoriteCount > 0 {
                Button("View Favorites", action: showFavorites)
                    .buttonStyle(.bordered)
                    .tint(.yellow)
            }
        }
    }

    private var summary: String {
        if vm.deletionCount == 0 && vm.favoriteCount == 0 {
            return "You reviewed every photo. Nothing marked for deletion."
        }
        var parts: [String] = []
        if vm.deletionCount > 0 { parts.append("marked \(vm.deletionCount) photo(s) for deletion") }
        if vm.favoriteCount > 0 { parts.append("favorited \(vm.favoriteCount) photo(s)") }
        return "You " + parts.joined(separator: " and ") + "."
    }
}
