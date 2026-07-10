import SwiftUI
import SwiftData

struct WallpaperDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var engine: WallpaperEngine
    
    let wallpaper: WallpaperItem
    
    @State private var selectedDisplayID: CGDirectDisplayID? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            previewPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(wallpaper.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                
                infoSection
                
                Divider()
                
                displaySection
                
                Spacer()
                
                actionButtons
            }
            .padding(24)
            .frame(width: 300)
        }
    }
    
    private var previewPane: some View {
        ZStack {
            if let url = wallpaper.resolvedURL,
               wallpaper.fileType == .liveVideo,
               let nsImage = NSImage(contentsOf: url) {
                // Fallback: show first frame thumbnail for videos
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.black)
            } else if let url = wallpaper.thumbnailURL,
                      let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let url = wallpaper.resolvedURL,
                      let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .background(Color.black)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoRow(label: "Type", value: wallpaper.fileType.displayName)
            if let width = wallpaper.width, let height = wallpaper.height {
                InfoRow(label: "Resolution", value: "\(width) × \(height)")
            }
            if let duration = wallpaper.duration {
                InfoRow(label: "Duration", value: String(format: "%.1f s", duration))
            }
            InfoRow(label: "Added", value: wallpaper.dateAdded.formatted(date: .abbreviated, time: .shortened))
        }
    }
    
    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display")
                .font(.headline)
            
            Picker("Display", selection: $selectedDisplayID) {
                Text("All Displays").tag(nil as CGDirectDisplayID?)
                ForEach(NSScreen.screens, id: \.self) { screen in
                    if let id = screen.displayID {
                        Text(screen.localizedName).tag(id as CGDirectDisplayID?)
                    }
                }
            }
            .pickerStyle(.radioGroup)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                engine.apply(wallpaper, to: selectedDisplayID)
            } label: {
                Label("Apply Wallpaper", systemImage: "checkmark.rectangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            
            HStack {
                Button {
                    wallpaper.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Label(wallpaper.isFavorite ? "Unfavorite" : "Favorite", systemImage: wallpaper.isFavorite ? "heart.slash" : "heart")
                }
                
                Spacer()
                
                Button(role: .destructive) {
                    ImportService.shared.delete(wallpaper)
                    modelContext.delete(wallpaper)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
    }
}
