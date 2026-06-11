//
//  ReviewStore.swift
//  swipeout (SwipeClean)
//
//  Persists review state locally using UserDefaults:
//    - Which photos have already been reviewed (over the app's full lifespan).
//    - The persistent "pending deletion" folder (photos marked for deletion but
//      not yet actually deleted), so the user can stop and resume any time.
//    - The user's chosen browse mode (asked only the first time).
//    - Whether to show photos that have already been reviewed.
//
//  No analytics, no network — everything stays on device.
//

import Foundation

/// A photo marked for deletion but not yet deleted. Persisted as JSON.
struct PendingDeletion: Codable, Equatable, Identifiable {
    let id: String          // PHAsset local identifier
    var estimatedBytes: Int64
}

/// Abstraction over the review-state persistence so it can be tested and
/// mirrored reactively by the view models.
protocol ReviewTracking: AnyObject {
    /// Photos already reviewed over the app's full lifespan.
    var reviewedIDs: Set<String> { get }
    /// Persistent list of photos marked for deletion, awaiting confirmation.
    var pendingDeletions: [PendingDeletion] { get }
    /// The browse mode chosen by the user (nil = never chosen → first run).
    var selectedMode: BrowseMode? { get }
    /// Whether already-reviewed photos should be shown again in new sessions.
    var showAlreadyReviewed: Bool { get }

    func markReviewed(_ id: String)
    func unmarkReviewed(_ id: String)

    func addPending(_ pending: PendingDeletion)
    func removePending(ids: Set<String>)
    func clearPending()

    func setSelectedMode(_ mode: BrowseMode?)
    func setShowAlreadyReviewed(_ value: Bool)

    /// Clears the lifetime reviewed history (the same photos will be shown again).
    func clearReviewHistory()
}

/// UserDefaults-backed implementation of `ReviewTracking`.
final class ReviewStore: ReviewTracking {

    private enum Keys {
        static let reviewedIDs = "review.lifetime.reviewedIDs"
        static let pending = "review.pendingDeletions"
        static let selectedMode = "review.selectedMode"
        static let showReviewed = "review.showAlreadyReviewed"
    }

    private let store: KeyValueStore

    nonisolated init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
    }

    // MARK: Reviewed set

    var reviewedIDs: Set<String> {
        let array = store.object(forKey: Keys.reviewedIDs) as? [String] ?? []
        return Set(array)
    }

    func markReviewed(_ id: String) {
        var set = reviewedIDs
        set.insert(id)
        store.set(Array(set) as Any?, forKey: Keys.reviewedIDs)
    }

    func unmarkReviewed(_ id: String) {
        var set = reviewedIDs
        set.remove(id)
        store.set(Array(set) as Any?, forKey: Keys.reviewedIDs)
    }

    func clearReviewHistory() {
        store.removeObject(forKey: Keys.reviewedIDs)
    }

    // MARK: Pending deletions

    var pendingDeletions: [PendingDeletion] {
        guard let data = store.object(forKey: Keys.pending) as? Data,
              let decoded = try? JSONDecoder().decode([PendingDeletion].self, from: data) else {
            return []
        }
        return decoded
    }

    func addPending(_ pending: PendingDeletion) {
        var list = pendingDeletions
        guard !list.contains(where: { $0.id == pending.id }) else { return }
        list.append(pending)
        persistPending(list)
    }

    func removePending(ids: Set<String>) {
        let list = pendingDeletions.filter { !ids.contains($0.id) }
        persistPending(list)
    }

    func clearPending() {
        store.removeObject(forKey: Keys.pending)
    }

    private func persistPending(_ list: [PendingDeletion]) {
        if let data = try? JSONEncoder().encode(list) {
            store.set(data as Any?, forKey: Keys.pending)
        }
    }

    // MARK: Selected mode

    var selectedMode: BrowseMode? {
        guard let data = store.object(forKey: Keys.selectedMode) as? Data,
              let decoded = try? JSONDecoder().decode(BrowseMode.self, from: data) else {
            return nil
        }
        return decoded
    }

    func setSelectedMode(_ mode: BrowseMode?) {
        guard let mode else {
            store.removeObject(forKey: Keys.selectedMode)
            return
        }
        if let data = try? JSONEncoder().encode(mode) {
            store.set(data as Any?, forKey: Keys.selectedMode)
        }
    }

    // MARK: Show already reviewed

    var showAlreadyReviewed: Bool {
        store.object(forKey: Keys.showReviewed) as? Bool ?? false
    }

    func setShowAlreadyReviewed(_ value: Bool) {
        store.set(value as Any?, forKey: Keys.showReviewed)
    }
}

/// In-memory `ReviewTracking` for tests and for sessions that don't persist.
final class InMemoryReviewTracker: ReviewTracking {
    private(set) var reviewedIDs: Set<String> = []
    private(set) var pendingDeletions: [PendingDeletion] = []
    private(set) var selectedMode: BrowseMode?
    private(set) var showAlreadyReviewed: Bool = false

    init() {}

    func markReviewed(_ id: String) { reviewedIDs.insert(id) }
    func unmarkReviewed(_ id: String) { reviewedIDs.remove(id) }

    func addPending(_ pending: PendingDeletion) {
        guard !pendingDeletions.contains(where: { $0.id == pending.id }) else { return }
        pendingDeletions.append(pending)
    }
    func removePending(ids: Set<String>) {
        pendingDeletions.removeAll { ids.contains($0.id) }
    }
    func clearPending() { pendingDeletions.removeAll() }

    func setSelectedMode(_ mode: BrowseMode?) { selectedMode = mode }
    func setShowAlreadyReviewed(_ value: Bool) { showAlreadyReviewed = value }

    func clearReviewHistory() { reviewedIDs.removeAll() }
}
