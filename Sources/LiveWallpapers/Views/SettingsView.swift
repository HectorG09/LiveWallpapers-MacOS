import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var engine: WallpaperEngine
    @EnvironmentObject private var energyManager: EnergyManager
    @Query private var settingsList: [AppSettings]
    @State private var unsplashStatus: String = ""
    
    private var settings: AppSettings? { settingsList.first }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Energy Efficiency") {
                    Toggle("Pause live wallpapers on battery", isOn: binding(forKeyPath: \.pauseOnBattery))
                    Toggle("Pause when Low Power Mode is on", isOn: binding(forKeyPath: \.pauseOnLowPower))
                    Toggle("Pause under serious thermal pressure", isOn: binding(forKeyPath: \.pauseOnThermalPressure))
                    Toggle("Pause when a fullscreen app is active", isOn: binding(forKeyPath: \.pauseWhenFullscreenApp))
                    Toggle("Fallback to static image on battery", isOn: binding(forKeyPath: \.fallbackToStaticOnBattery))
                }
                
                Section("Auto Change") {
                    Toggle("Automatically change wallpaper", isOn: binding(forKeyPath: \.autoChangeEnabled))
                    
                    HStack {
                        Text("Interval")
                        Spacer()
                        Picker("", selection: binding(forKeyPath: \.autoChangeIntervalSeconds)) {
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                            Text("15 minutes").tag(900.0)
                            Text("30 minutes").tag(1800.0)
                            Text("1 hour").tag(3600.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                    
                    Toggle("Only auto-change when on AC power", isOn: binding(forKeyPath: \.autoChangeOnlyOnAC))
                }
                
                Section("Online Source") {
                    Toggle("Enable Unsplash sample wallpapers", isOn: binding(forKeyPath: \.unsplashEnabled))
                    TextField("Unsplash Access Key", text: binding(forKeyPath: \.unsplashAccessKey))
                    Button("Load 10 sample wallpapers") {
                        loadUnsplashSamples()
                    }
                    .disabled(settings?.unsplashAccessKey.isEmpty != false)
                    if !unsplashStatus.isEmpty {
                        Text(unsplashStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Get a free key at unsplash.com/developers. Images are used under the Unsplash license with attribution.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Spacer()
        }
        .frame(width: 500, height: 500)
    }
    
    private func binding<T>(forKeyPath keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { settings?[keyPath: keyPath] ?? defaultValue(for: keyPath) },
            set: { newValue in
                settings?[keyPath: keyPath] = newValue
                try? settings?.modelContext?.save()
                energyManager.updateShouldPause()
            }
        )
    }
    
    private func defaultValue<T>(for keyPath: KeyPath<AppSettings, T>) -> T {
        let defaultSettings = AppSettings()
        return defaultSettings[keyPath: keyPath]
    }
    
    private func loadUnsplashSamples() {
        guard let accessKey = settings?.unsplashAccessKey, !accessKey.isEmpty else {
            unsplashStatus = "Missing access key"
            return
        }
        
        unsplashStatus = "Loading..."
        Task {
            do {
                let photos = try await UnsplashService.fetchCurated(accessKey: accessKey, count: 10)
                for photo in photos {
                    let item = UnsplashService.wallpaperItem(from: photo, categoryID: "nature")
                    if let imageURL = URL(string: photo.urls.regular) {
                        let data = try await UnsplashService.downloadImage(from: imageURL)
                        let (localURL, thumbURL) = try await ImportService.shared.saveDownloadedData(
                            data,
                            filename: "unsplash_\(photo.id).jpg",
                            title: item.title
                        )
                        item.localPath = localURL.path
                        item.thumbnailPath = thumbURL.path
                    }
                    modelContext.insert(item)
                }
                try? modelContext.save()
                await MainActor.run {
                    unsplashStatus = "Loaded \(photos.count) wallpapers"
                }
            } catch {
                await MainActor.run {
                    unsplashStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
