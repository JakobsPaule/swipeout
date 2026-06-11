//
//  LibraryViewModel.swift
//  swipeout (SwipeClean)
//
//  App-level coordinator: permission state, album list, session creation,
//  confirmed deletion, and lifetime stats.
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class LibraryViewModel {

    private(set) var access: LibraryAccess
    private(set) var albums: [AlbumInfo] = []
    private(set) var lifetimeStats: LifetimeStats
    private(set) var isLoading = false

    /// Result of the most recent confirmed deletion, for the success screen.
    var lastDeletionResult: DeletionResult?
    var errorMessage: String?

    @ObservationIgnored private let service: PhotoLibraryServicing
    @ObservationIgnored private let statsStore: StatsStore

    struct DeletionResult: Equatable {
        let photosDeleted: Int
        let bytesFreed: Int64
    }

    init(service: PhotoLibraryServicing = PhotoLibraryService(),
         statsStore: StatsStore = StatsStore()) {
        self.service = service
        self.statsStore = statsStore
        self.access = service.currentAccess
        self.lifetimeStats = statsStore.load()
    }

    // MARK: Permissions

    func refreshAccess() {
        access = service.currentAccess
    }

    func requestAccess() async {
        access = await service.requestAccess()
        if access.canAccessAnyPhotos {
            loadAlbums()
        }
    }

    // MARK: Albums

    func loadAlbums() {
        isLoading = true
        let fetched = service.fetchAlbums()
        albums = fetched
        isLoading = false
    }

    // MARK: Sessions

    /// Builds a swipe session for the given mode by fetching the relevant photos.
    func makeSession(for mode: BrowseMode) -> SwipeSessionViewModel {
        let items = service.fetchPhotos(for: mode)
        return SwipeSessionViewModel(mode: mode, items: items, service: service)
    }

    // MARK: Confirmed deletion

    /// Executes the deletion queue through PhotoKit and updates lifetime stats.
    func confirmDeletion(for session: SwipeSessionViewModel) async {
        let queue = session.deletionQueue
        guard !queue.isEmpty else { return }

        let items = queue.map(\.photo)
        let totalBytes = queue.reduce(Int64(0)) { $0 + $1.estimatedBytes }

        do {
            try await service.deleteAssets(items)
            let ids = Set(items.map(\.id))
            session.purgeDeletedFromSession(ids: ids)

            lifetimeStats = statsStore.recordDeletion(
                photoCount: items.count, bytesFreed: totalBytes)
            lastDeletionResult = DeletionResult(
                photosDeleted: items.count, bytesFreed: totalBytes)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: Stats

    func refreshStats() {
        lifetimeStats = statsStore.load()
    }

    func resetStats() {
        statsStore.reset()
        lifetimeStats = statsStore.load()
    }
}
