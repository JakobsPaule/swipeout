//
//  FavoritesView.swift
//  swipeout (Library Control)
//
//  The persistent Favorites folder ("super likes"). Photos swiped up in any
//  session collect here, most recently favorited first. Driven by the
//  persistent ReviewStore via LibraryViewModel, so it survives stopping and
//  resuming.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(LibraryViewModel.self) private var library
    @Binding var path: NavigationPath

    @State private var items: [PhotoItem] = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView("No Favorites Yet", systemImage: "star",
                                       description: Text("Swipe up on a photo to favorite it — it'll show up here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items) { item in
                            FavoriteThumbnail(item: item) {
                                library.removeFromFavorites(item.id)
                                reload()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .appBackground()
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func reload() {
        items = library.loadFavoriteItems()
    }
}

struct FavoriteThumbnail: View {
    let item: PhotoItem
    let onRemove: () -> Void
    @Environment(LibraryViewModel.self) private var library
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: onRemove) {
                Image(systemName: "star.slash.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .yellow)
            }
            .padding(4)
            .accessibilityLabel("Remove from Favorites")
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: item.id) {
            image = await library.loadImage(for: item,
                                            targetSize: CGSize(width: 200, height: 200))
        }
    }
}
