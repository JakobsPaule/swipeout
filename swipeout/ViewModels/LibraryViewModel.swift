//
//  LibraryViewModel.swift
//  swipeout (Library Control)
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

    // MARK: Review state (mirrors the persistent ReviewStore reactively)
    /// The browse mode chosen by the user. `nil` means the user has never
    /// chosen one yet → the mode selector is shown on first run.
    private(set) var selectedMode: BrowseMode?
    /// Whether sessions should include photos already reviewed in the past.
    private(set) var showAlreadyReviewed: Bool
    /// Count of photos in the persistent pending-deletion folder.
    private(set) var pendingCount: Int
    /// Count of photos reviewed over the app's lifetime.
    private(set) var reviewedCount: Int
    /// Count of photos in the persistent Favorites folder ("super likes").
    private(set) var favoritesCount: Int
    /// The album the down-swipe gesture moves photos into (nil = not set yet).
    private(set) var defaultAlbum: AlbumRef?

    /// Result of the most recent confirmed deletion, for the success screen.
    var lastDeletionResult: DeletionResult?
    var errorMessage: String?

    @ObservationIgnored private let service: PhotoLibraryServicing
    @ObservationIgnored private let statsStore: StatsStore
    @ObservationIgnored private let reviewStore: ReviewTracking

    struct DeletionResult: Equatable {
        let photosDeleted: Int
        let bytesFreed: Int64
    }

    init(service: PhotoLibraryServicing = PhotoLibraryService(),
         statsStore: StatsStore = StatsStore(),
         reviewStore: ReviewTracking = ReviewStore()) {
        self.service = service
        self.statsStore = statsStore
        self.reviewStore = reviewStore
        self.access = service.currentAccess
        self.lifetimeStats = statsStore.load()
        self.selectedMode = reviewStore.selectedMode
        self.showAlreadyReviewed = reviewStore.showAlreadyReviewed
        self.pendingCount = reviewStore.pendingDeletions.count
        self.reviewedCount = reviewStore.reviewedIDs.count
        self.favoritesCount = reviewStore.favoriteIDs.count
        self.defaultAlbum = reviewStore.defaultAlbum
    }

    /// Re-reads review state from the persistent store into the observed
    /// mirrors. Call when a view appears so badges/counts stay fresh after a
    /// swipe session mutated the store directly.
    func refreshReviewState() {
        selectedMode = reviewStore.selectedMode
        showAlreadyReviewed = reviewStore.showAlreadyReviewed
        pendingCount = reviewStore.pendingDeletions.count
        reviewedCount = reviewStore.reviewedIDs.count
        favoritesCount = reviewStore.favoriteIDs.count
        defaultAlbum = reviewStore.defaultAlbum
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

    /// Persists the album the down-swipe gesture moves photos into.
    func setDefaultAlbum(_ album: AlbumRef?) {
        reviewStore.setDefaultAlbum(album)
        defaultAlbum = album
    }

    /// Creates a new, empty album and adds it to the loaded album list.
    func createAlbum(named title: String) async throws -> AlbumInfo {
        let album = try await service.createAlbum(named: title)
        albums.append(album)
        return album
    }

    // MARK: Mode selection

    /// Persists the user's chosen browse mode. The mode selector is only shown
    /// on first run (when `selectedMode == nil`); afterwards the mode is changed
    /// from Settings.
    func selectMode(_ mode: BrowseMode) {
        reviewStore.setSelectedMode(mode)
        selectedMode = mode
    }

    /// Toggles whether already-reviewed photos are included in new sessions.
    func setShowAlreadyReviewed(_ value: Bool) {
        reviewStore.setShowAlreadyReviewed(value)
        showAlreadyReviewed = value
    }

    /// Clears the lifetime reviewed history. After this the user will be shown
    /// the same photos again.
    func clearReviewHistory() {
        reviewStore.clearReviewHistory()
        reviewedCount = 0
    }

    // MARK: Sessions

    /// Builds a swipe session for the given mode by fetching the relevant photos.
    /// Photos already reviewed in the past are filtered out unless the user has
    /// opted to see them again. Items already in the pending folder are also
    /// excluded so they aren't queued twice. Wires the session to the persistent
    /// review store so reviewed/pending state survives stopping and resuming.
    func makeSession(for mode: BrowseMode) -> SwipeSessionViewModel {
        var items = service.fetchPhotos(for: mode)
        let pendingIDs = Set(reviewStore.pendingDeletions.map(\.id))
        items.removeAll { pendingIDs.contains($0.id) }
        if !showAlreadyReviewed {
            let reviewed = reviewStore.reviewedIDs
            items.removeAll { reviewed.contains($0.id) }
        }
        return SwipeSessionViewModel(mode: mode, items: items,
                                     service: service, tracker: reviewStore)
    }

    /// Photo counts per calendar month, used by the date-range picker's
    /// zoomable timeline. Computed on demand (metadata-only enumeration).
    func monthBuckets() -> [MonthBucket] {
        service.photoMonthBuckets()
    }

    // MARK: Pending-deletion folder (persistent)

    /// Loads the photos currently in the persistent pending-deletion folder.
    func loadPendingDeletionItems() -> [DeletionItem] {
        let pending = reviewStore.pendingDeletions
        let items = service.fetchItems(withIDs: pending.map(\.id))
        let bytesByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0.estimatedBytes) })
        return items.map { DeletionItem(photo: $0, estimatedBytes: bytesByID[$0.id] ?? 0) }
    }

    /// Estimated total bytes in the pending-deletion folder.
    var pendingEstimatedBytes: Int64 {
        reviewStore.pendingDeletions.reduce(0) { $0 + $1.estimatedBytes }
    }

    /// Removes a single photo from the pending-deletion folder (keeps the photo).
    func removeFromPending(_ id: String) {
        reviewStore.removePending(ids: [id])
        pendingCount = reviewStore.pendingDeletions.count
    }

    // MARK: Favorites folder ("super likes", persistent)

    /// Loads the photos currently favorited, most recently favorited first
    /// (i.e. newest favorites are at the top).
    func loadFavoriteItems() -> [PhotoItem] {
        service.fetchItems(withIDs: reviewStore.favoriteIDs)
    }

    /// Removes a single photo from the Favorites folder (keeps the photo).
    func removeFromFavorites(_ id: String) {
        reviewStore.removeFavorite(id)
        favoritesCount = reviewStore.favoriteIDs.count
    }

    /// Permanently deletes everything in the pending folder via PhotoKit
    /// (sends to "Recently Deleted") and updates lifetime stats.
    func confirmPendingDeletion() async {
        let pending = reviewStore.pendingDeletions
        guard !pending.isEmpty else { return }

        let items = service.fetchItems(withIDs: pending.map(\.id))
        guard !items.isEmpty else {
            reviewStore.clearPending()
            pendingCount = 0
            return
        }
        let bytesByID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0.estimatedBytes) })
        let totalBytes = items.reduce(Int64(0)) { $0 + (bytesByID[$1.id] ?? 0) }

        do {
            try await service.deleteAssets(items)
            let ids = Set(items.map(\.id))
            reviewStore.removePending(ids: ids)
            pendingCount = reviewStore.pendingDeletions.count
            reviewStore.removeFavorites(ids: ids)
            favoritesCount = reviewStore.favoriteIDs.count

            lifetimeStats = statsStore.recordDeletion(
                photoCount: items.count, bytesFreed: totalBytes)
            lastDeletionResult = DeletionResult(
                photosDeleted: items.count, bytesFreed: totalBytes)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
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
            reviewStore.removePending(ids: ids)
            pendingCount = reviewStore.pendingDeletions.count
            reviewStore.removeFavorites(ids: ids)
            favoritesCount = reviewStore.favoriteIDs.count

            lifetimeStats = statsStore.recordDeletion(
                photoCount: items.count, bytesFreed: totalBytes)
            lastDeletionResult = DeletionResult(
                photosDeleted: items.count, bytesFreed: totalBytes)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: Image loading (for the pending-deletion folder)

    func loadImage(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await service.loadImage(for: item, targetSize: targetSize)
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
