//
//  swipeoutApp.swift
//  swipeout (SwipeClean)
//

import SwiftUI

@main
struct swipeoutApp: App {
    @State private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
        }
    }
}
