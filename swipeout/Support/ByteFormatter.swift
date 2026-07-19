//
//  ByteFormatter.swift
//  swipeout (Library Control)
//
//  Formatting helpers for storage figures.
//

import Foundation

enum StorageFormat {
    /// Formats a byte count as GB with two decimal places, e.g. "1.23 GB".
    static func gigabytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        return String(format: "%.2f GB", gb)
    }

    /// Formats a raw Double GB value with two decimals.
    static func gigabytes(_ gb: Double) -> String {
        String(format: "%.2f GB", gb)
    }

    /// Human-friendly adaptive size string (KB/MB/GB) for thumbnails/lists.
    static func humanReadable(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
