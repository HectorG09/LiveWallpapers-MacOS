# LiveWallpapers

A native macOS live wallpaper app inspired by Wallper.app. Browse, import, and apply static images, dynamic HEIC sets, and MP4/MOV live video wallpapers across one or multiple displays.

## Features

- **Native macOS app** built with SwiftUI + AppKit.
- **Live video wallpapers** (MP4/MOV) using a desktop-level window with hardware-accelerated `AVPlayer`.
- **Static and dynamic HEIC wallpapers** applied via `NSWorkspace`.
- **Gallery UI** similar to Wallper.app: sidebar categories, masonry grid, preview/detail panel.
- **Energy efficiency**:
  - Auto-pause live videos on battery power.
  - Auto-pause on Low Power Mode.
  - Auto-pause under serious thermal pressure.
  - Auto-pause when a fullscreen app covers the desktop.
  - Auto-pause during display sleep / screensaver / system sleep.
  - Optional fallback to a static image on battery.
- **Auto-change wallpapers** on a configurable timer, with an option to change only on AC power.
- **Multi-display support** with per-display or all-display assignment.
- **Menu-bar-only** app with no Dock icon.
- **Optional Unsplash integration** for sample static wallpapers (requires a free Unsplash API key).

## Requirements

- macOS 14.0 or later.
- Xcode 16+ or Swift 6.0+ toolchain.
- For distribution outside the Mac App Store: code signing + notarization.

## Download

The latest compiled app is available in the [Releases](https://github.com/HectorG09/LiveWallpapers/releases) section:

- **[LiveWallpapers v1.0.0](https://github.com/HectorG09/LiveWallpapers/releases/tag/v1.0.0)**

Download `LiveWallpapers.zip`, extract it, and double-click `LiveWallpapers.app`.

## Build & Run

### From the command line

```bash
swift build
```

To run the raw executable (UI will be limited without a proper `.app` bundle):

```bash
./.build/debug/LiveWallpapers
```

### As a macOS app bundle

A pre-built bundle is provided at `LiveWallpapers.app`. To refresh it after code changes:

```bash
swift build
rm -rf LiveWallpapers.app
mkdir -p LiveWallpapers.app/Contents/MacOS
cp .build/debug/LiveWallpapers LiveWallpapers.app/Contents/MacOS/LiveWallpapers
# Info.plist is already included in the repo
xattr -cr LiveWallpapers.app
open LiveWallpapers.app
```

### Open in Xcode

Open `Package.swift` directly in Xcode. It will recognize the Swift package as a macOS project. To enable sandbox entitlements or code signing for distribution, convert the package to an Xcode project or configure signing in Xcode.

## Usage

1. Launch the app. It lives in the menu bar.
2. Click the menu-bar icon or the default launch window to open the gallery.
3. Click **Import** to add your own JPG, PNG, HEIC, MP4, or MOV files.
4. Select a wallpaper and click **Apply Wallpaper**.
5. Open **Settings** to configure energy-saving behavior, auto-change intervals, and optional Unsplash samples.

## Project Structure

```
Sources/LiveWallpapers/
├── App/
│   ├── LiveWallpapersApp.swift   # @main entry point
│   └── AppDelegate.swift          # Menu bar, model container seeding
├── Models/
│   ├── WallpaperItem.swift        # SwiftData model
│   ├── Category.swift             # Built-in categories
│   ├── AppSettings.swift          # User preferences
│   └── WallpaperFileType.swift    # File type detection
├── Services/
│   ├── WallpaperEngine.swift      # Apply/pause wallpapers across displays
│   ├── WallpaperWindowController.swift  # Video wallpaper window
│   ├── EnergyManager.swift        # Battery/thermal/sleep/fullscreen monitoring
│   ├── ImportService.swift        # File import & local caching
│   ├── ThumbnailGenerator.swift   # Image/video thumbnails
│   └── UnsplashService.swift      # Optional online samples
└── Views/
    ├── GalleryView.swift
    ├── SidebarView.swift
    ├── WallpaperGridView.swift
    ├── WallpaperDetailView.swift
    └── SettingsView.swift
```

## Important Notes

- **No copyrighted content is included.** Wallpapers must be imported by you or fetched from legitimate sources such as Unsplash.
- **Live video wallpapers** rely on a window-level technique (placing a borderless `NSWindow` just below the desktop icon layer). This is the same approach used by established open-source projects, but behavior may vary across macOS updates.
- **Lock screen wallpapers**: macOS does not provide a public API for third-party apps to draw video on the lock screen.
- **Sandboxing**: the app is configured with a minimal sandbox. For persistent access to imported folders, you may need to store security-scoped bookmarks or disable sandboxing during local development.

## License

This project is provided as-is for personal/educational use. It does not distribute wallpapers or scrape third-party catalogs.
