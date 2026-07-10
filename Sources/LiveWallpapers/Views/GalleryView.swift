import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var engine: WallpaperEngine
    @EnvironmentObject private var energyManager: EnergyManager
    
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var wallpapers: [WallpaperItem]
    @Query private var settingsList: [AppSettings]
    
    @State private var selectedCategoryID: String = "all"
    @State private var searchText: String = ""
    @State private var selectedWallpaper: WallpaperItem?
    @State private var showingImportSheet = false
    @State private var showingSettings = false
    @State private var showingAddURL = false
    @State private var isTargetedForDrop = false
    
    private var settings: AppSettings? { settingsList.first }
    
    private var filteredWallpapers: [WallpaperItem] {
        wallpapers.filter { item in
            let matchesCategory: Bool
            switch selectedCategoryID {
            case "all":
                matchesCategory = true
            case "favorites":
                matchesCategory = item.isFavorite
            case "live":
                matchesCategory = item.fileType == .liveVideo
            default:
                matchesCategory = item.categoryID == selectedCategoryID
            }
            
            let matchesSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText)
            
            return matchesCategory && matchesSearch
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                categories: categories,
                selectedCategoryID: $selectedCategoryID
            )
            .frame(minWidth: 200)
        } detail: {
            WallpaperGridView(
                wallpapers: filteredWallpapers,
                selectedWallpaper: $selectedWallpaper
            )
            .searchable(text: $searchText, prompt: "Search wallpapers")
            .toolbar {
                ToolbarItem {
                    Button {
                        importFiles()
                    } label: {
                        Label("Import", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button {
                        showingAddURL = true
                    } label: {
                        Label("Add URL", systemImage: "link")
                    }
                }
                ToolbarItem {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .sheet(item: $selectedWallpaper) { wallpaper in
                WallpaperDetailView(wallpaper: wallpaper)
                    .frame(minWidth: 700, minHeight: 500)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .frame(width: 500, height: 500)
            }
            .sheet(isPresented: $showingAddURL) {
                AddFromURLView(categories: categories)
                    .frame(width: 450, height: 260)
            }
            .dropDestination(for: URL.self) { urls, location in
                importDroppedURLs(urls)
                return true
            } isTargeted: { targeted in
                isTargetedForDrop = targeted
            }
        }
        .onAppear {
            updateAutoChange()
        }
        .onChange(of: settings?.autoChangeEnabled) { updateAutoChange() }
        .onChange(of: settings?.autoChangeIntervalSeconds) { updateAutoChange() }
        .onChange(of: settings?.autoChangeOnlyOnAC) { updateAutoChange() }
    }
    
    private func importDroppedURLs(_ urls: [URL]) {
        Task {
            var imported: [WallpaperItem] = []
            for url in urls {
                let items = await ImportService.shared.importURL(url, defaultCategoryID: selectedCategoryID)
                imported.append(contentsOf: items)
            }
            await MainActor.run {
                for item in imported {
                    modelContext.insert(item)
                }
                try? modelContext.save()
            }
        }
    }
    
    private func importFiles() {
        ImportService.shared.importFiles(categoryID: selectedCategoryID) { items in
            for item in items {
                modelContext.insert(item)
            }
            try? modelContext.save()
        }
    }
    
    private func updateAutoChange() {
        guard let settings else {
            engine.stopAutoChange()
            return
        }
        
        if settings.autoChangeEnabled {
            engine.startAutoChange(
                with: filteredWallpapers,
                interval: settings.autoChangeIntervalSeconds,
                onlyOnAC: settings.autoChangeOnlyOnAC
            )
        } else {
            engine.stopAutoChange()
        }
    }
}
