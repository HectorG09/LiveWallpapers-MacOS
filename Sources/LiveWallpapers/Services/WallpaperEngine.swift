import AppKit
import AVFoundation
import Combine
import SwiftData

@MainActor
final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()
    
    @Published var currentWallpaper: WallpaperItem?
    @Published var isPaused: Bool = false
    @Published var appliedDisplayIDs: Set<CGDirectDisplayID> = []
    
    private var displayControllers: [CGDirectDisplayID: WallpaperWindowController] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var autoChangeTimer: Timer?
    private var wallpaperQueue: [WallpaperItem] = []
    private var currentQueueIndex: Int = 0
    
    private init() {
        setupDisplayObserver()
    }
    
    // MARK: - Display Management
    
    private func setupDisplayObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconcileDisplayControllers()
            }
            .store(in: &cancellables)
    }
    
    private func reconcileDisplayControllers() {
        let screens = NSScreen.screens
        var activeIDs = Set<CGDirectDisplayID>()
        
        for screen in screens {
            guard let displayID = screen.displayID else { continue }
            activeIDs.insert(displayID)
            
            if let controller = displayControllers[displayID] {
                controller.updateFrame(screen.frame)
            } else {
                let controller = WallpaperWindowController(screen: screen)
                displayControllers[displayID] = controller
                
                // Re-apply current wallpaper if any
                if let wallpaper = currentWallpaper {
                    apply(wallpaper, to: displayID)
                }
            }
        }
        
        // Remove controllers for disconnected displays
        for id in displayControllers.keys where !activeIDs.contains(id) {
            displayControllers[id]?.window?.close()
            displayControllers.removeValue(forKey: id)
        }
        
        appliedDisplayIDs = Set(displayControllers.keys)
    }
    
    func ensureControllersExist() {
        if displayControllers.isEmpty {
            print("LiveWallpapers: creating display controllers for \(NSScreen.screens.count) screen(s)")
            reconcileDisplayControllers()
        }
    }
    
    // MARK: - Apply Wallpaper
    
    func apply(_ wallpaper: WallpaperItem, to specificDisplay: CGDirectDisplayID? = nil) {
        print("LiveWallpapers: applying wallpaper '\(wallpaper.title)' (type: \(wallpaper.fileType))")
        ensureControllersExist()
        currentWallpaper = wallpaper
        
        guard let url = wallpaper.resolvedURL else {
            print("LiveWallpapers: no local URL for wallpaper \(wallpaper.title)")
            return
        }
        print("LiveWallpapers: resolved URL \(url.path)")
        
        let targetIDs: [CGDirectDisplayID]
        if let specificDisplay {
            targetIDs = [specificDisplay]
        } else {
            targetIDs = Array(displayControllers.keys)
        }
        
        switch wallpaper.fileType {
        case .liveVideo:
            print("LiveWallpapers: applying live video to \(targetIDs.count) display(s)")
            for id in targetIDs {
                displayControllers[id]?.setVideo(url: url)
            }
            // Clear static desktop image so the video shows cleanly
            setStaticDesktopImage(nil, for: targetIDs)
            
        case .staticImage, .dynamicHeic:
            stopVideoWallpapers(for: targetIDs)
            setStaticDesktopImage(url, for: targetIDs)
        }
        
        setPaused(isPaused)
    }
    
    func clearWallpaper() {
        currentWallpaper = nil
        stopAllVideos()
        setStaticDesktopImage(nil, for: Array(displayControllers.keys))
    }
    
    // MARK: - Static Desktop Image
    
    private func setStaticDesktopImage(_ url: URL?, for displayIDs: [CGDirectDisplayID]) {
        let workspace = NSWorkspace.shared
        let screens = NSScreen.screens
        
        for screen in screens {
            guard let displayID = screen.displayID, displayIDs.contains(displayID) else { continue }
            
            do {
                if let url {
                    try workspace.setDesktopImageURL(url, for: screen, options: [:])
                } else {
                    // Restore a neutral color if no image
                    var options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                        .allowClipping: false
                    ]
                    options[.fillColor] = NSColor.black
                    // Use a tiny transparent/black image or system default
                    if let defaultURL = defaultWallpaperURL() {
                        try workspace.setDesktopImageURL(defaultURL, for: screen, options: options)
                    }
                }
            } catch {
                print("Failed to set desktop image for display \(displayID): \(error)")
            }
        }
    }
    
    private func defaultWallpaperURL() -> URL? {
        // macOS system default wallpaper
        URL(fileURLWithPath: "/System/Library/Desktop Pictures/Big Sur Graphic.heic")
    }
    
    // MARK: - Video Control
    
    private func stopVideoWallpapers(for displayIDs: [CGDirectDisplayID]) {
        for id in displayIDs {
            displayControllers[id]?.stopVideo()
        }
    }
    
    private func stopAllVideos() {
        for controller in displayControllers.values {
            controller.stopVideo()
        }
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
        for controller in displayControllers.values {
            controller.setPaused(paused)
        }
    }
    
    // MARK: - Auto Change
    
    func startAutoChange(with wallpapers: [WallpaperItem], interval: TimeInterval, onlyOnAC: Bool) {
        stopAutoChange()
        wallpaperQueue = wallpapers
        currentQueueIndex = 0
        guard !wallpapers.isEmpty, interval > 0 else { return }
        
        autoChangeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if onlyOnAC && EnergyManager.shared.isOnBattery { return }
                self.advanceQueue()
            }
        }
    }
    
    func stopAutoChange() {
        autoChangeTimer?.invalidate()
        autoChangeTimer = nil
    }
    
    private func advanceQueue() {
        guard !wallpaperQueue.isEmpty else { return }
        currentQueueIndex = (currentQueueIndex + 1) % wallpaperQueue.count
        let wallpaper = wallpaperQueue[currentQueueIndex]
        apply(wallpaper)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
