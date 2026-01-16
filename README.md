# GitY

A modern macOS Git client written in Swift, inspired by GitX.

<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="GitY Icon" width="128" height="128">
</p>

## Overview

GitY is a complete rewrite of the classic GitX application in Swift, featuring the same familiar UI and functionality with modern macOS technologies.

## Screenshots

Coming soon...

## Installation

### Using Homebrew (Recommended)

The easiest way to install GitY is via Homebrew Cask:

```bash
brew tap dongri/tap
brew install --cask gity
```

### Manual Installation (DMG)

1. Download `GitY.dmg` from the [latest release](https://github.com/dongri/gity/releases/latest).
2. Open the DMG file.
3. Drag `GitY.app` to the **Applications** folder.
4. **Important**: You must run the following command in Terminal to allow the app to run (removes Gatekeeper quarantine):

   ```bash
   xattr -cr /Applications/GitY.app
   ```
   
5. Launch GitY from Applications.

### From Source
```bash
git clone https://github.com/dongri/gity.git
cd gity
xcodebuild -project GitY.xcodeproj -scheme GitY -configuration Release build
```

## Command Line Tool

After installing GitY, you can install the `gity` command line tool:

1. Open GitY
2. Go to **Settings** > **Integration**
3. Click **Install Command Line Tools**

Then use it from Terminal:

```bash
gity                      # Open current directory
gity .                    # Open current directory
gity /path/to/repo        # Open specific repository
```

## Features

- 📁 **Repository Browser** - Navigate through your Git repository with ease
- 📜 **Commit History** - View detailed commit history with diffs
- ✏️ **Stage View** - Stage and unstage files with visual feedback
- 🌿 **Branch Management** - Create, checkout, and delete branches
- 🔄 **Remote Operations** - Fetch, pull, and push to remotes
- 📦 **Stash Support** - Save, apply, pop, and drop stashes
- 📂 **Submodule Support** - View and manage Git submodules
- 🔍 **Diff Viewer** - Syntax-highlighted diff viewing
- ⚡ **Performance Optimized** - Asynchronous loading for smooth UI
- 🖥️ **Command Line Tool** - Open repositories from Terminal

## Requirements

- macOS 13.0 or later
- Git installed (usually at `/usr/bin/git`)

## Building from Source

### Requirements
- Xcode 15.0 or later
- macOS 13.0 or later

### Build Steps

#### Using Xcode
1. Open `GitY.xcodeproj` in Xcode
2. Select the GitY scheme
3. Build and run (⌘R)

#### Using Command Line
```bash
# Clone the repository
git clone https://github.com/dongri/gity.git
cd gity

# Build
xcodebuild -project GitY.xcodeproj -scheme GitY -configuration Release build

# The app will be in DerivedData
open ~/Library/Developer/Xcode/DerivedData/GitY-*/Build/Products/Release/GitY.app
```

## Architecture

GitY is built using SwiftUI and follows a clean architecture:

```
Sources/
├── GitYApp.swift              # App entry point
├── Models/
│   ├── GitRepository.swift    # Core repository model (async Git operations)
│   ├── GitRef.swift           # Branch/Tag references
│   ├── GitCommit.swift        # Commit model
│   ├── ChangedFile.swift      # File changes
│   ├── GitStash.swift         # Stash model
│   └── GitSubmodule.swift     # Submodule model
├── Views/
│   ├── ContentView.swift      # Main content view
│   ├── WelcomeView.swift      # Welcome screen
│   ├── MainRepositoryView.swift # Repository view
│   ├── SidebarView.swift      # Navigation sidebar
│   ├── StageView.swift        # Staging area
│   ├── HistoryView.swift      # Commit history
│   ├── DiffView.swift         # Diff viewer
│   └── PreferencesView.swift  # Settings (including CLI install)
└── Utils/
    ├── DirectoryWatcher.swift
    └── RelativeDateFormatter.swift
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

GitY is released under the MIT License. See [LICENSE](LICENSE) for details.

## Credits

- Original GitX by Pieter de Bie
- Swift rewrite inspired by the original Objective-C implementation

---

Made with ❤️ in Swift
