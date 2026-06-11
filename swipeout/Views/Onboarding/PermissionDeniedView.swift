//
//  PermissionDeniedView.swift
//  swipeout (SwipeClean)
//
//  Friendly empty state shown when access is denied or restricted.
//

import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Photos Access Needed", systemImage: "lock.slash")
        } description: {
            Text("SwipeClean can’t review your photos without permission. You can enable access in Settings. Everything still happens privately on your device.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("openSettingsButton")
        }
        .padding()
    }
}

#Preview {
    PermissionDeniedView()
}
