//
//  BrowseMode.swift
//  swipeout (SwipeClean)
//
//  Defines how photos are ordered / sourced for a swipe session.
//

import Foundation

/// The way photos are ordered or sourced within a swipe session.
enum BrowseMode: Equatable, Hashable, Codable {
    /// All photos, newest creation date first.
    case newestFirst
    /// All photos, oldest creation date first.
    case oldestFirst
    /// All photos in a shuffled, non-repeating order.
    case random
    /// Photos from a specific album (user album or smart album).
    case album(id: String, title: String)
    /// Photos created within a custom date range (manual override; newest first).
    case dateRange(start: Date, end: Date)

    /// A stable, user-facing label.
    var title: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        case .random: return "Random"
        case .album(_, let title): return title
        case .dateRange(let start, let end):
            return BrowseMode.rangeLabel(start: start, end: end)
        }
    }

    /// SF Symbol used in the mode selector.
    var systemImage: String {
        switch self {
        case .newestFirst: return "arrow.down.to.line"
        case .oldestFirst: return "arrow.up.to.line"
        case .random: return "shuffle"
        case .album: return "rectangle.stack"
        case .dateRange: return "calendar"
        }
    }

    /// "Jan 2022 – Mar 2023" style label for a date range.
    private static func rangeLabel(start: Date, end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        let a = f.string(from: start)
        let b = f.string(from: end)
        return a == b ? a : "\(a) – \(b)"
    }
}

/// A month-granularity bucket of photo counts, used by the date-range picker
/// to show how many photos exist in each year/month.
struct MonthBucket: Identifiable, Equatable {
    let year: Int
    let month: Int   // 1...12
    let count: Int

    var id: Int { year * 100 + month }

    /// First instant of this month.
    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// Last instant of this month (start of next month minus 1 second).
    var endDate: Date {
        let cal = Calendar.current
        let next = cal.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        return next.addingTimeInterval(-1)
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
