//
//  swipeoutApp.swift
//  swipeout (Library Control)
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
