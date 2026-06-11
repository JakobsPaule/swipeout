//
//  LibraryAccess.swift
//  swipeout (SwipeClean)
//
//  App-level mirror of PHAuthorizationStatus so the UI and view
//  models don't depend directly on PhotoKit enums.
//

import Foundation
import Photos

enum LibraryAccess: Equatable {
    case notDetermined
    case denied
    case restricted
    case limited
    case authorized

    init(status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .limited: self = .limited
        case .authorized: self = .authorized
        @unknown default: self = .denied
        }
    }

    /// Whether the app can read at least some assets.
    var canAccessAnyPhotos: Bool {
        self == .authorized || self == .limited
    }
}
