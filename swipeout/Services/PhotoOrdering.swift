//
//  PhotoOrdering.swift
//  swipeout (SwipeClean)
//
//  Pure ordering helpers, separated from PhotoKit so they can be
//  unit-tested deterministically.
//

import Foundation

enum PhotoOrdering {

    /// Orders items for the given mode.
    /// - Note: `.random` uses the supplied generator so tests can be deterministic.
    static func order(_ items: [PhotoItem],
                      for mode: BrowseMode,
                      using generator: inout some RandomNumberGenerator) -> [PhotoItem] {
        switch mode {
        case .newestFirst:
            return items.sorted { sortKey($0) > sortKey($1) }
        case .oldestFirst:
            return items.sorted { sortKey($0) < sortKey($1) }
        case .random:
            return items.shuffled(using: &generator)
        case .album, .dateRange:
            // Ordering is handled by the fetch (album / date order preserved);
            // default here to newest-first as a stable fallback.
            return items.sorted { sortKey($0) > sortKey($1) }
        }
    }

    /// Convenience overload using the system random generator.
    static func order(_ items: [PhotoItem], for mode: BrowseMode) -> [PhotoItem] {
        var generator = SystemRandomNumberGenerator()
        return order(items, for: mode, using: &generator)
    }

    /// Sort key: items missing a creation date sort to the end for newest-first
    /// (treated as distantPast) which keeps ordering stable and predictable.
    private static func sortKey(_ item: PhotoItem) -> Date {
        item.creationDate ?? .distantPast
    }
}
