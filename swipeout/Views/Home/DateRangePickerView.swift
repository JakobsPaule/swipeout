//
//  DateRangePickerView.swift
//  swipeout (Library Control)
//
//  A manual override for starting a session over a custom date range, chosen
//  by browsing the library's timeline the way the Photos app does: a zoomable
//  grid that pinches between Years and Months. Pick a start month and an end
//  month, then start cleaning that slice.
//
//  This does NOT change the saved browse mode, so the app's normal
//  "resume where you left off" behaviour is untouched — it's a one-off session.
//

import SwiftUI

struct DateRangePickerView: View {
    @Binding var path: NavigationPath
    @Environment(LibraryViewModel.self) private var library

    enum Zoom { case years, months }

    @State private var buckets: [MonthBucket] = []
    @State private var loaded = false
    @State private var zoom: Zoom = .years
    @State private var focusedYear: Int?
    /// Selection endpoints stored as month ids (year*100 + month).
    @State private var selStart: Int?
    @State private var selEnd: Int?
    @State private var showStartConfirm = false

    private let yearColumns = [GridItem(.adaptive(minimum: 96), spacing: 12)]
    private let monthColumns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        VStack(spacing: 16) {
            header

            if !loaded {
                ProgressView("Reading your timeline…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if buckets.isEmpty {
                ContentUnavailableView("No Photos", systemImage: "calendar",
                                       description: Text("There are no dated photos to browse."))
            } else {
                ScrollView { grid.padding(.horizontal) }
                    .gesture(zoomGesture)
                footer
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .navigationTitle("Browse by Date")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Start with this date range?",
                            isPresented: $showStartConfirm, titleVisibility: .visible) {
            Button("Make this my place & start") { start(persist: true) }
            Button("Just this once") { start(persist: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“Make this my place” saves the range as your browse mode, so next time you tap Start Cleaning you'll resume right here. “Just this once” keeps your current place untouched.")
        }
        .task {
            if !loaded {
                buckets = library.monthBuckets()
                focusedYear = years.first
                loaded = true
            }
        }
    }

    // MARK: Header / footer

    private var header: some View {
        VStack(spacing: 6) {
            if zoom == .months, let y = focusedYear {
                HStack {
                    Button {
                        withAnimation(.snappy) { zoom = .years }
                    } label: {
                        Label("\(y.description)", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            Text(zoom == .years
                 ? "Pinch to zoom into a year, or tap one. Pick a start and an end."
                 : "Tap a start month, then an end month. Pinch out for years.")
                .font(.caption)
                .foregroundStyle(Color.appSubtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            if let (lo, hi) = rangeBounds {
                Text("\(label(forID: lo)) – \(label(forID: hi)) · \(selectedCount) photos")
                    .font(.subheadline)
                    .foregroundStyle(Color.appText)
            } else {
                Text("No range selected")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSubtext)
            }

            HStack(spacing: 12) {
                Button("Clear") { selStart = nil; selEnd = nil }
                    .buttonStyle(.glass())
                    .disabled(selStart == nil)

                Button("Start Cleaning") { showStartConfirm = true }
                    .buttonStyle(.glass(prominent: true))
                    .disabled(rangeBounds == nil || selectedCount == 0)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: Grid

    @ViewBuilder
    private var grid: some View {
        switch zoom {
        case .years:
            LazyVGrid(columns: yearColumns, spacing: 12) {
                ForEach(years, id: \.self) { year in
                    cell(title: year.description,
                         subtitle: "\(yearCount(year))",
                         selected: isYearSelected(year)) {
                        withAnimation(.snappy) {
                            focusedYear = year
                            zoom = .months
                        }
                    }
                }
            }
        case .months:
            LazyVGrid(columns: monthColumns, spacing: 12) {
                ForEach(months(in: focusedYear ?? years.first ?? 0)) { bucket in
                    cell(title: monthName(bucket.month),
                         subtitle: "\(bucket.count)",
                         selected: isSelected(bucket.id)) {
                        toggle(bucket.id)
                    }
                }
            }
        }
    }

    private func cell(title: String, subtitle: String, selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(Color.appSubtext)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.appText.opacity(0.18) : Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.appText : .white.opacity(0.25),
                                  lineWidth: selected ? 2 : 1)
            }
            .foregroundStyle(Color.appText)
        }
        .buttonStyle(.plain)
    }

    // MARK: Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onEnded { value in
                withAnimation(.snappy) {
                    if value > 1.2 {
                        if zoom == .years { focusedYear = focusedYear ?? years.first; zoom = .months }
                    } else if value < 0.85 {
                        zoom = .years
                    }
                }
            }
    }

    // MARK: Selection

    private func toggle(_ id: Int) {
        if selStart == nil {
            selStart = id
        } else if selEnd == nil {
            selEnd = id
        } else {
            selStart = id
            selEnd = nil
        }
    }

    private var rangeBounds: (Int, Int)? {
        if let a = selStart, let b = selEnd { return (min(a, b), max(a, b)) }
        if let a = selStart { return (a, a) }
        return nil
    }

    private func isSelected(_ id: Int) -> Bool {
        guard let (lo, hi) = rangeBounds else { return false }
        return id >= lo && id <= hi
    }

    private func isYearSelected(_ year: Int) -> Bool {
        guard let (lo, hi) = rangeBounds else { return false }
        return year >= lo / 100 && year <= hi / 100
    }

    private var selectedCount: Int {
        buckets.filter { isSelected($0.id) }.reduce(0) { $0 + $1.count }
    }

    // MARK: Data helpers

    private var years: [Int] {
        Array(Set(buckets.map(\.year))).sorted(by: >)
    }

    private func months(in year: Int) -> [MonthBucket] {
        buckets.filter { $0.year == year }.sorted { $0.month < $1.month }
    }

    private func yearCount(_ year: Int) -> Int {
        months(in: year).reduce(0) { $0 + $1.count }
    }

    private func monthName(_ month: Int) -> String {
        let symbols = DateFormatter().shortMonthSymbols ?? []
        return (1...12).contains(month) ? symbols[month - 1] : "\(month)"
    }

    private func label(forID id: Int) -> String {
        "\(monthName(id % 100)) \(id / 100)"
    }

    // MARK: Start

    /// Starts a session for the chosen range. When `persist` is true the range
    /// becomes the saved browse mode (so a later "Start Cleaning" resumes here);
    /// otherwise it's a one-off and the user's current place is left untouched.
    private func start(persist: Bool) {
        guard let (lo, hi) = rangeBounds else { return }
        let startDate = MonthBucket(year: lo / 100, month: lo % 100, count: 0).startDate
        let endDate = MonthBucket(year: hi / 100, month: hi % 100, count: 0).endDate
        let mode = BrowseMode.dateRange(start: startDate, end: endDate)
        if persist { library.selectMode(mode) }
        path.append(Route.swipe(mode: mode))
    }
}
