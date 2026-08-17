//
//  StatsStore.swift
//  swipeout (Library Control)
//
//  Persists lifetime deletion statistics locally using UserDefaults.
//  No analytics, no network — everything stays on device.
//

import Foundation

/// Snapshot of lifetime statistics.
struct LifetimeStats: Equatable {
    var totalPhotosDeleted: Int
    var totalBytesFreed: Int64
    /// Total seconds spent in active swipe sessions across the app's lifetime.
    var totalTimeSpentSeconds: Int

    static let zero = LifetimeStats(totalPhotosDeleted: 0, totalBytesFreed: 0, totalTimeSpentSeconds: 0)

    /// Estimated GB freed (decimal GB, i.e. bytes / 1e9).
    var gigabytesFreed: Double {
        Double(totalBytesFreed) / 1_000_000_000
    }

    /// Human-readable formatting for total time spent (e.g. "1h 23m", "45 min", "30 sec").
    var formattedTimeSpent: String {
        let h = totalTimeSpentSeconds / 3600
        let m = (totalTimeSpentSeconds % 3600) / 60
        let s = totalTimeSpentSeconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) min" }
        return "\(s) sec"
    }

    /// Minutes of sorting time per GB of storage freed. `nil` if nothing freed yet.
    var minutesPerGigabyte: Double? {
        guard gigabytesFreed > 0 else { return nil }
        return Double(totalTimeSpentSeconds) / 60.0 / gigabytesFreed
    }
}

/// Abstraction so view models can be tested with an in-memory backing store.
protocol KeyValueStore: AnyObject {
    func integer(forKey key: String) -> Int
    func object(forKey key: String) -> Any?
    func set(_ value: Int, forKey key: String)
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {}

/// In-memory key/value store for unit tests.
final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Any] = [:]

    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Int, forKey key: String) { storage[key] = value }
    func set(_ value: Any?, forKey key: String) {
        if let value { storage[key] = value } else { storage.removeValue(forKey: key) }
    }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
}

/// Stores and updates lifetime deletion statistics.
final class StatsStore {
    private enum Keys {
        static let totalPhotos = "stats.lifetime.totalPhotosDeleted"
        static let totalBytes  = "stats.lifetime.totalBytesFreed"
        static let totalTime   = "stats.lifetime.totalTimeSpentSeconds"
    }

    nonisolated(unsafe) private let store: KeyValueStore

    nonisolated init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
    }

    /// Current persisted lifetime stats.
    func load() -> LifetimeStats {
        let photos = store.integer(forKey: Keys.totalPhotos)
        // Int64 is stored as NSNumber; read defensively.
        let bytes   = (store.object(forKey: Keys.totalBytes) as? NSNumber)?.int64Value ?? 0
        let seconds = store.integer(forKey: Keys.totalTime)
        return LifetimeStats(totalPhotosDeleted: photos,
                             totalBytesFreed: bytes,
                             totalTimeSpentSeconds: seconds)
    }

    /// Adds a completed deletion batch to the lifetime totals and returns the new totals.
    @discardableResult
    func recordDeletion(photoCount: Int, bytesFreed: Int64) -> LifetimeStats {
        var stats = load()
        stats.totalPhotosDeleted += max(0, photoCount)
        stats.totalBytesFreed    += max(0, bytesFreed)
        persist(stats)
        return stats
    }

    /// Accumulates active-session seconds into the lifetime time-spent total.
    @discardableResult
    func recordSessionTime(seconds: Int) -> LifetimeStats {
        guard seconds > 0 else { return load() }
        var stats = load()
        stats.totalTimeSpentSeconds += seconds
        persist(stats)
        return stats
    }

    /// Clears lifetime counters only. Does not touch any photos.
    func reset() {
        store.removeObject(forKey: Keys.totalPhotos)
        store.removeObject(forKey: Keys.totalBytes)
        store.removeObject(forKey: Keys.totalTime)
    }

    private func persist(_ stats: LifetimeStats) {
        store.set(stats.totalPhotosDeleted,           forKey: Keys.totalPhotos)
        store.set(NSNumber(value: stats.totalBytesFreed), forKey: Keys.totalBytes)
        store.set(stats.totalTimeSpentSeconds,        forKey: Keys.totalTime)
    }
}
