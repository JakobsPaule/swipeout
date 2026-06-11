//
//  ReviewDeletionsView.swift
//  swipeout (SwipeClean)
//
//  Shows all photos queued for deletion with thumbnails, count, and
//  estimated storage. Requires explicit confirmation before deleting.
//

import SwiftUI

struct ReviewDeletionsView: View {
    var session: SwipeSessionViewModel
    @Environment(LibraryViewModel.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var showConfirm = false
    @State private var isDeleting = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if library.lastDeletionResult != nil {
                    DeletionSuccessView(result: library.lastDeletionResult!) {
                        library.lastDeletionResult = nil
                        dismiss()
                    }
                } else if session.deletionQueue.isEmpty {
                    ContentUnavailableView("Nothing to Review", systemImage: "trash.slash",
                                           description: Text("You haven’t marked any photos for deletion."))
                } else {
                    reviewList
                }
            }
            .navigationTitle("Review Deletions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Delete \(session.deletionCount) photo(s)?", isPresented: $showConfirm) {
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
        }
    }

    private var reviewList: some View {
        VStack(spacing: 0) {
            summaryHeader
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(session.deletionQueue) { dItem in
                        DeletionThumbnail(item: dItem, session: session) {
                            session.removeFromQueue(dItem)
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
            Label("\(session.deletionCount) photos", systemImage: "photo.stack")
            Spacer()
            Label("≈ \(StorageFormat.gigabytes(session.estimatedBytesQueued))", systemImage: "internaldrive")
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
            .accessibilityIdentifier("confirmDeletionButton")

            Text("Photos move to iOS “Recently Deleted”. Permanent removal is handled by the Photos app.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func performDeletion() async {
        isDeleting = true
        await library.confirmDeletion(for: session)
        isDeleting = false
    }
}

struct DeletionThumbnail: View {
    let item: DeletionItem
    let session: SwipeSessionViewModel
    let onRemove: () -> Void
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
            image = await session.loadImage(for: item.photo,
                                            targetSize: CGSize(width: 200, height: 200))
        }
    }
}

struct DeletionSuccessView: View {
    let result: LibraryViewModel.DeletionResult
    let onDone: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Cleaned Up!", systemImage: "sparkles")
        } description: {
            VStack(spacing: 6) {
                Text("\(result.photosDeleted) photo(s) moved to Recently Deleted.")
                Text("≈ \(StorageFormat.gigabytes(result.bytesFreed)) will be freed.")
                Text("Open the Photos app to permanently remove them, or let iOS clear them automatically after 30 days.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } actions: {
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("deletionDoneButton")
        }
    }
}
