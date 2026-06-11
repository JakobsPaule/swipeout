//
//  PendingDeletionsView.swift
//  swipeout (SwipeClean)
//
//  The persistent "marked for deletion" folder. Photos swiped left across any
//  number of sessions collect here until the user explicitly confirms deletion.
//  Driven by the persistent ReviewStore via LibraryViewModel, so it survives
//  stopping and resuming.
//

import SwiftUI

struct PendingDeletionsView: View {
    @Environment(LibraryViewModel.self) private var library
    @Binding var path: NavigationPath

    @State private var items: [DeletionItem] = []
    @State private var showConfirm = false
    @State private var isDeleting = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        Group {
            if library.lastDeletionResult != nil {
                DeletionSuccessView(result: library.lastDeletionResult!) {
                    library.lastDeletionResult = nil
                    path = NavigationPath()
                }
            } else if items.isEmpty {
                ContentUnavailableView("Nothing Marked", systemImage: "trash.slash",
                                       description: Text("You haven’t marked any photos for deletion yet."))
            } else {
                folderList
            }
        }
        .navigationTitle("Marked for Deletion")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete \(items.count) photo(s)?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await performDeletion() }
            }
        } message: {
            Text("These photos will be moved to your iOS “Recently Deleted” album, where they stay for 30 days before iOS removes them permanently.")
        }
        .alert("Deletion Failed",
               isPresented: Binding(get: { library.errorMessage != nil },
                                    set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        .onAppear { reload() }
    }

    private var folderList: some View {
        VStack(spacing: 0) {
            summaryHeader
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { dItem in
                        PendingThumbnail(item: dItem) {
                            library.removeFromPending(dItem.id)
                            reload()
                        }
                    }
                }
                .padding()
            }
            confirmBar
        }
    }

    private var summaryHeader: some View {
        HStack {
            Label("\(items.count) photos", systemImage: "photo.stack")
            Spacer()
            Label("≈ \(StorageFormat.gigabytes(library.pendingEstimatedBytes))",
                  systemImage: "internaldrive")
        }
        .font(.subheadline)
        .padding()
        .background(.thinMaterial)
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            Button {
                showConfirm = true
            } label: {
                if isDeleting {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 6)
                } else {
                    Text("Confirm Deletion")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeleting)
            .accessibilityIdentifier("confirmPendingDeletionButton")

            Text("Photos move to iOS “Recently Deleted”. Permanent removal is handled by the Photos app.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func reload() {
        items = library.loadPendingDeletionItems()
    }

    private func performDeletion() async {
        isDeleting = true
        await library.confirmPendingDeletion()
        isDeleting = false
        reload()
    }
}

struct PendingThumbnail: View {
    let item: DeletionItem
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
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
            }
            .padding(4)
            .accessibilityLabel("Remove from deletion list")
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: item.id) {
            image = await library.loadImage(for: item.photo,
                                            targetSize: CGSize(width: 200, height: 200))
        }
    }
}
