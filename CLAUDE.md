# Swipeout — iOS App

## Project Overview
**Swipeout** is a native iOS application built with Swift.
> ⚠️ Update this section once the app concept is defined.

## Tech Stack
- **Language:** Swift
- **Platform:** iOS
- **UI Framework:** SwiftUI (default — update if UIKit is used)
- **Minimum iOS Target:** TBD
- **Package Manager:** Swift Package Manager (SPM)

## Project Structure
```
swipeout/
├── Swipeout/               # Main app source
│   ├── App/                # App entry point & configuration
│   ├── Views/              # SwiftUI views
│   ├── ViewModels/         # View models (MVVM)
│   ├── Models/             # Data models
│   ├── Services/           # Networking, persistence, etc.
│   └── Resources/          # Assets, fonts, localisation
├── SwipeoutTests/          # Unit tests
├── SwipeoutUITests/        # UI tests
└── CLAUDE.md               # This file
```

## Architecture
**MVVM** (Model–View–ViewModel) is the preferred pattern.

## Developer
- Paul Jakob (`p.jakob-93@web.de`)
- Environment: macOS / Xcode, BCG Platinion network (Zscaler proxy)

## Git Conventions
- Branch naming: `feature/<name>`, `fix/<name>`, `chore/<name>`
- Commit style: short imperative subject line (e.g. `Add login screen`)
- Push to personal GitHub remote (`origin`)

## Notes
- Zscaler SSL inspection is active on the network — set `NODE_EXTRA_CA_CERTS` / CA bundle if additional tooling is added
- Keep secrets out of source control — use `Secrets.swift` (gitignored) or Xcode environment variables
