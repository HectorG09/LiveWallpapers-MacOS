import SwiftUI

struct WallpaperGridView: View {
    let wallpapers: [WallpaperItem]
    @Binding var selectedWallpaper: WallpaperItem?
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if wallpapers.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(wallpapers) { wallpaper in
                        WallpaperCell(wallpaper: wallpaper)
                            .onTapGesture {
                                selectedWallpaper = wallpaper
                            }
                    }
                }
                .padding(20)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No wallpapers yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Import your own images or videos to get started.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WallpaperCell: View {
    let wallpaper: WallpaperItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if wallpaper.fileType == .liveVideo {
                    LiveBadge()
                        .padding(8)
                }
                
                if wallpaper.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            
            Text(wallpaper.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            
            HStack {
                Text(wallpaper.fileType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let width = wallpaper.width, let height = wallpaper.height {
                    Text("\(width)×\(height)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumbnailURL = wallpaper.thumbnailURL,
           let nsImage = NSImage(contentsOf: thumbnailURL) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = wallpaper.resolvedURL,
                  let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }
}

struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: 8))
            Text("LIVE")
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.red)
        .foregroundStyle(.white)
        .clipShape(Capsule())
    }
}
