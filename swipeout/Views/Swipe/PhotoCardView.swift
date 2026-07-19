//
//  PhotoCardView.swift
//  swipeout (Library Control)
//
//  A single full-screen photo card. Loads its image lazily through the
//  session view model and exposes drag-to-swipe with keep/delete/favorite
//  ("super like") overlays.
//

import SwiftUI

struct PhotoCardView: View {
    let item: PhotoItem
    let session: SwipeSessionViewModel
    /// The album the down-swipe gesture moves photos into (nil = not set yet).
    let defaultAlbum: AlbumRef?
    /// Called when a swipe gesture commits with the resulting decision.
    let onCommit: (_ decision: SwipeDecision) -> Void
    /// Called when the user swipes down but no default album has been chosen yet.
    let onMissingDefaultAlbum: () -> Void

    @State private var image: UIImage?
    @State private var translation: CGSize = .zero
    @State private var isLoading = true

    private let threshold: CGFloat = 120
    private let verticalThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else if isLoading {
                    ProgressView()
                } else {
                    ContentUnavailableView("Couldn’t load photo", systemImage: "photo")
                }

                // Decision overlays.
                overlayLabel(text: "KEEP", color: .green, opacity: keepOpacity, rotation: -18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(28)
                overlayLabel(text: "DELETE", color: .red, opacity: deleteOpacity, rotation: 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(28)
                overlayLabel(text: "FAVORITE", color: .yellow, opacity: favoriteOpacity, rotation: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 28)
                overlayLabel(text: "MOVE", color: .blue, opacity: moveOpacity, rotation: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 28)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(x: translation.width, y: translation.height * (isVerticalDrag ? 1 : 0.2))
            .rotationEffect(.degrees(isVerticalDrag ? 0 : Double(translation.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { translation = $0.translation }
                    .onEnded { value in
                        let t = value.translation
                        if isVerticalDrag(t) && t.height < -verticalThreshold {
                            commit(decision: .favorite, screenSize: geo.size)
                        } else if isVerticalDrag(t) && t.height > verticalThreshold {
                            if let defaultAlbum {
                                commit(decision: .moveToAlbum(albumID: defaultAlbum.id, albumTitle: defaultAlbum.title),
                                       screenSize: geo.size)
                            } else {
                                withAnimation(.spring) { translation = .zero }
                                onMissingDefaultAlbum()
                            }
                        } else if !isVerticalDrag(t) && t.width < -threshold {
                            commit(decision: .delete, screenSize: geo.size)
                        } else if !isVerticalDrag(t) && t.width > threshold {
                            commit(decision: .keep, screenSize: geo.size)
                        } else {
                            withAnimation(.spring) { translation = .zero }
                        }
                    }
            )
            .task(id: item.id) {
                isLoading = true
                let target = CGSize(width: geo.size.width * UIScreen.main.scale,
                                    height: geo.size.height * UIScreen.main.scale)
                image = await session.loadImage(for: item, targetSize: target)
                isLoading = false
            }
        }
        .accessibilityIdentifier("photoCard")
    }

    /// Whether the current drag reads as vertical (favorite) rather than
    /// horizontal (keep/delete), based on which axis moved further.
    private func isVerticalDrag(_ t: CGSize) -> Bool { abs(t.height) > abs(t.width) }
    private var isVerticalDrag: Bool { isVerticalDrag(translation) }

    private var keepOpacity: Double {
        isVerticalDrag ? 0 : Double(max(0, translation.width) / threshold)
    }
    private var deleteOpacity: Double {
        isVerticalDrag ? 0 : Double(max(0, -translation.width) / threshold)
    }
    private var favoriteOpacity: Double {
        isVerticalDrag ? Double(max(0, -translation.height) / verticalThreshold) : 0
    }
    private var moveOpacity: Double {
        isVerticalDrag ? Double(max(0, translation.height) / verticalThreshold) : 0
    }

    private func overlayLabel(text: String, color: Color, opacity: Double, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
            .opacity(min(1, opacity))
    }

    private func commit(decision: SwipeDecision, screenSize: CGSize) {
        withAnimation(.easeOut(duration: 0.25)) {
            switch decision {
            case .delete:
                translation = CGSize(width: -screenSize.width * 1.5, height: translation.height)
            case .keep:
                translation = CGSize(width: screenSize.width * 1.5, height: translation.height)
            case .favorite:
                translation = CGSize(width: translation.width, height: -screenSize.height * 1.5)
            case .moveToAlbum:
                translation = CGSize(width: translation.width, height: screenSize.height * 1.5)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onCommit(decision)
            translation = .zero
        }
    }
}
