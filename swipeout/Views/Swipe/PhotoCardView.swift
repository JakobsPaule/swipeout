//
//  PhotoCardView.swift
//  swipeout (SwipeClean)
//
//  A single full-screen photo card. Loads its image lazily through the
//  session view model and exposes drag-to-swipe with keep/delete overlays.
//

import SwiftUI

struct PhotoCardView: View {
    let item: PhotoItem
    let session: SwipeSessionViewModel
    /// Called when a swipe gesture commits. `true` = delete, `false` = keep.
    let onCommit: (_ delete: Bool) -> Void

    @State private var image: UIImage?
    @State private var translation: CGSize = .zero
    @State private var isLoading = true

    private let threshold: CGFloat = 120

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
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(x: translation.width, y: translation.height * 0.2)
            .rotationEffect(.degrees(Double(translation.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { translation = $0.translation }
                    .onEnded { value in
                        if value.translation.width < -threshold {
                            commit(delete: true, screenWidth: geo.size.width)
                        } else if value.translation.width > threshold {
                            commit(delete: false, screenWidth: geo.size.width)
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

    private var keepOpacity: Double { Double(max(0, translation.width) / threshold) }
    private var deleteOpacity: Double { Double(max(0, -translation.width) / threshold) }

    private func overlayLabel(text: String, color: Color, opacity: Double, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
            .opacity(min(1, opacity))
    }

    private func commit(delete: Bool, screenWidth: CGFloat) {
        withAnimation(.easeOut(duration: 0.25)) {
            translation.width = delete ? -screenWidth * 1.5 : screenWidth * 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onCommit(delete)
            translation = .zero
        }
    }
}
