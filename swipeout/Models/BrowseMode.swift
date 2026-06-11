//
//  BrowseMode.swift
//  swipeout (SwipeClean)
//
//  Defines how photos are ordered / sourced for a swipe session.
//

import Foundation

/// The way photos are ordered or sourced within a swipe session.
enum BrowseMode: Equatable, Hashable {
    /// All photos, newest creation date first.
    case newestFirst
    /// All photos, oldest creation date first.
    case oldestFirst
    /// All photos in a shuffled, non-repeating order.
    case random
    /// Photos from a specific album (user album or smart album).
    case album(id: String, title: String)

    /// A stable, user-facing label.
    var title: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        case .random: return "Random"
        case .album(_, let title): return title
        }
    }

    /// SF Symbol used in the mode selector.
    var systemImage: String {
        switch self {
        case .newestFirst: return "arrow.down.to.line"
        case .oldestFirst: return "arrow.up.to.line"
        case .random: return "shuffle"
        case .album: return "rectangle.stack"
        }
    }
}

/// High-level category of browsing, used by the mode selector UI.
enum BrowseCategory: String, CaseIterable, Identifiable {
    case chronological
    case random
    case album

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chronological: return "Chronological"
        case .random: return "Random"
        case .album: return "Album"
        }
    }

    var systemImage: String {
        switch self {
        case .chronological: return "clock"
        case .random: return "shuffle"
        case .album: return "rectangle.stack"
        }
    }
}
