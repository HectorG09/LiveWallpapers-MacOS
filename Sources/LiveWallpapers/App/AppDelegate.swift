import AppKit
import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var wallpaperEngine = WallpaperEngine.shared
    private lazy var energyManager = EnergyManager.shared
    
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        
        setupStatusItem()
        setupModelContainer()
        setupEnergyManagement()
        
        // Open gallery on launch
        openGalleryWindow()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    private func setupModelContainer() {
        let schema = Schema([
            WallpaperItem.self,
            Category.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            seedBuiltInCategories()
            seedDefaultSettings()
        } catch {
            print("Failed to create model container: \(error)")
        }
    }
    
    private func seedBuiltInCategories() {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Category>()
        do {
            let existing = try context.fetch(descriptor)
            let existingIDs = Set(existing.map(\.id))
            for category in Category.builtIn where !existingIDs.contains(category.id) {
                context.insert(category)
            }
            try context.save()
        } catch {
            print("Failed to seed categories: \(error)")
        }
    }
    
    private func seedDefaultSettings() {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<AppSettings>(predicate: #Predicate { $0.id == "default" })
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                context.insert(AppSettings())
                try context.save()
            }
        } catch {
            print("Failed to seed settings: \(error)")
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "photo.fill.on.rectangle.fill", accessibilityDescription: "Live Wallpapers")
        button.action = #selector(statusItemClicked)
        button.target = self
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Gallery", action: #selector(openGalleryWindow), keyEquivalent: "g"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func statusItemClicked() {
        // Left-click opens gallery; right-click shows menu via NSStatusItem.menu
        openGalleryWindow()
    }
    
    @objc private func openGalleryWindow() {
        if let mainWindow, mainWindow.isVisible {
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = GalleryContainerView()
            .modelContainer(modelContainer!)
            .environmentObject(wallpaperEngine)
            .environmentObject(energyManager)
            .frame(minWidth: 900, minHeight: 600)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Live Wallpapers"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        mainWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openSettingsWindow() {
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = SettingsContainerView()
            .modelContainer(modelContainer!)
            .environmentObject(wallpaperEngine)
            .environmentObject(energyManager)
            .frame(width: 500, height: 500)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupEnergyManagement() {
        if let modelContainer {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<AppSettings>(predicate: #Predicate { $0.id == "default" })
            if let settings = try? context.fetch(descriptor).first {
                energyManager.configure(with: settings)
            }
        }
        
        energyManager.shouldPauseVideoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldPause in
                self?.wallpaperEngine.setPaused(shouldPause)
            }
            .store(in: &cancellables)
        
        energyManager.startMonitoring()
    }
}
