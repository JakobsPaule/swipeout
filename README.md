# SwipeClean

Regain control of your iPhone photo library. SwipeClean lets you review photos
one at a time with a Tinder-style swipe, queue clutter for deletion, and safely
remove it — moving photos to iOS **Recently Deleted** so nothing is lost by
accident.

> Bundle ID: `jp.swipeout` · Target: iOS 17+ · SwiftUI · PhotoKit

---

## Features

- **Photo access** with a clear, privacy-first permission prompt. Handles
  **full**, **limited**, and **denied** states gracefully.
- **Browsing modes**: newest-first, oldest-first, random (no repeats per
  session), and per-album (user albums + smart albums).
- **Swipe interaction**: swipe left to mark for deletion, right to keep. Buttons
  for Delete / Keep / Undo. Single-step **undo**. Live `current / total`
  progress.
- **Safe deletion**: nothing is deleted on swipe. A **review queue** shows
  thumbnails, count, and estimated storage. Deletion requires **explicit
  confirmation**, then runs through PhotoKit so photos land in iOS
  *Recently Deleted*.
- **Stats**: per-session results plus persisted **lifetime** totals (photos
  deleted, estimated GB freed) stored locally in `UserDefaults`.
- **Privacy**: no analytics, no uploads, no cloud processing — everything is
  on-device. Stated in onboarding and Settings.

## Architecture (MVVM)

```
swipeout/
├── Models/
│   ├── BrowseMode.swift        Browsing modes & categories
│   ├── PhotoItem.swift         Value wrapper over PHAsset; queue/undo models
│   └── LibraryAccess.swift     App-level mirror of PHAuthorizationStatus
├── Services/
│   ├── PhotoLibraryService.swift   All PhotoKit logic (permissions, fetch,
│   │                               image loading + caching, byte estimation,
│   │                               deletion)
│   ├── PhotoOrdering.swift     Pure, testable ordering helpers
│   └── StatsStore.swift        UserDefaults-backed lifetime stats
├── ViewModels/
│   ├── SwipeSessionViewModel.swift   Ordered list, deletion queue, undo, progress
│   └── LibraryViewModel.swift        Coordinator: permissions, albums, sessions,
│                                     confirmed deletion, stats
├── Views/
│   ├── Onboarding/  OnboardingView, PermissionDeniedView
│   ├── Home/        HomeView, ModeSelectorView
│   ├── Swipe/       SwipeContainerView, PhotoCardView
│   ├── Review/      ReviewDeletionsView (+ success view)
│   ├── Stats/       StatsView
│   └── Settings/    SettingsView
├── Support/         ByteFormatter (storage formatting)
└── ContentView.swift  → RootView (permission-driven routing)
```

The queue, ordering, and stats logic are deliberately decoupled from PhotoKit so
they can be unit-tested with an in-memory fake (`FakePhotoLibraryService`).

## Setup

1. Open `swipeout.xcodeproj` in Xcode 16+ (project uses file-system synchronized
   groups, so new files in the source folders are added to the target
   automatically).
2. Select your development team if prompted (Signing & Capabilities).
3. Build & run on a device or simulator running **iOS 17+**.

### Permissions

The Photos usage string is provided via the build setting
`INFOPLIST_KEY_NSPhotoLibraryUsageDescription` (the project uses an
auto-generated Info.plist). PhotoKit is requested with `.readWrite` access.

To exercise the full flow in the simulator, seed Photos with sample images
(drag images onto the simulator) and, if needed, reset permissions:

```bash
xcrun simctl privacy booted reset photos jp.swipeout
```

## Testing

- **Unit tests** (`swipeoutTests`): ordering correctness, swipe queue + undo,
  button/gesture equivalence, byte estimation, stats persistence & reset,
  confirmed-deletion success and failure paths.
- **UI tests** (`swipeoutUITests`): onboarding, permission grant, settings/reset,
  and the swipe → review → confirm flow. UI tests are written defensively and
  `XCTSkip` when the simulator has no photos or permission isn't granted, and
  they **cancel** the destructive confirmation so they never actually delete
  your photos.

Run from Xcode (⌘U) or:

```bash
xcodebuild test \
  -project swipeout.xcodeproj \
  -scheme swipeout \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Privacy model

- All photo review and deletion happens **locally on device**.
- **No** analytics, **no** network calls, **no** cloud processing.
- Lifetime stats are stored only in `UserDefaults` on the device.

## Known iOS limitations

- **Recently Deleted is final, not us**: SwipeClean cannot permanently delete
  photos. `PHAssetChangeRequest.deleteAssets` moves them to iOS *Recently
  Deleted*, where they remain ~30 days. Permanent removal happens in the Photos
  app or automatically after that window. This is an Apple platform constraint.
- **System confirmation**: iOS shows its own "Delete N Photos?" alert during the
  PhotoKit change. This is expected and required by the OS.
- **Storage estimates**: "GB freed" is an estimate from each asset's reported
  resource file size. Actual reclaimed space is realized only after photos leave
  Recently Deleted, and iCloud Photos optimization can affect on-device sizes.
- **Limited access**: with limited permission, only the user-selected photos are
  visible. SwipeClean surfaces this and links to Settings to manage the
  selection.
- **Recently Deleted album** is intentionally **not** accessed directly.

## License

Personal project. © Jakob Paul.
