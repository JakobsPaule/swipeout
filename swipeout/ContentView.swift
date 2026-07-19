//
//  ContentView.swift  →  RootView
//  swipeout (Library Control)
//
//  Decides which top-level screen to show based on Photos permission.
//

import SwiftUI

struct RootView: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch library.access {
                case .notDetermined:
                    OnboardingView()
                case .denied, .restricted:
                    PermissionDeniedView()
                case .limited, .authorized:
                    HomeView()
                }
            }
            .legibleOverBackground()
        }
        .fontDesign(.serif)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onChange(of: scenePhase) { _, phase in
            // Permissions can change in Settings while we're backgrounded.
            if phase == .active {
                library.refreshAccess()
                if library.access.canAccessAnyPhotos && library.albums.isEmpty {
                    library.loadAlbums()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(LibraryViewModel())
}
