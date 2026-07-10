import AppKit
import Foundation
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class ImportService {
    static let shared = ImportService()
    
    private let fileManager = FileManager.default
    
    private var supportDirectory: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first!.appendingPathComponent("LiveWallpapers", isDirectory: true)
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }
    
    var wallpapersDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("Wallpapers", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    var thumbnailsDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() {}
    
    func importFiles(categoryID: String = "all", completion: @escaping ([WallpaperItem]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [
            .image,
            .heic,
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "mov")!,
            UTType(filenameExtension: "mkv")!,
            UTType(filenameExtension: "avi")!
        ]
        
        panel.begin { [weak self] result in
            guard let self, result == .OK else {
                completion([])
                return
            }
            
            Task {
                var items: [WallpaperItem] = []
                for url in panel.urls {
                    let imported = await self.importURL(url, defaultCategoryID: categoryID)
                    items.append(contentsOf: imported)
                }
                await MainActor.run {
                    completion(items)
                }
            }
        }
    }
    
    func importURL(_ url: URL, defaultCategoryID: String) async -> [WallpaperItem] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        
        if isDirectory.boolValue {
            return await importDirectory(url, categoryID: defaultCategoryID)
        } else {
            guard let item = await importFile(url, categoryID: defaultCategoryID) else { return [] }
            return [item]
        }
    }
    
    private func importDirectory(_ url: URL, categoryID: String) async -> [WallpaperItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) else { return [] }
        
        var items: [WallpaperItem] = []
        for case let fileURL as URL in enumerator.allObjects {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                  resourceValues.isRegularFile == true else { continue }
            
            if let item = await importFile(fileURL, categoryID: categoryID) {
                items.append(item)
            }
        }
        return items
    }
    
    private func importFile(_ url: URL, categoryID: String) async -> WallpaperItem? {
        let fileType = WallpaperFileType.infer(from: url)
        let ext = url.pathExtension
        let uniqueName = "\(url.deletingPathExtension().lastPathComponent)_\(UUID().uuidString.prefix(8)).\(ext)"
        let destination = wallpapersDirectory.appendingPathComponent(uniqueName)
        
        do {
            try fileManager.copyItem(at: url, to: destination)
        } catch {
            print("Failed to copy \(url): \(error)")
            return nil
        }
        
        var thumbnailPath: String?
        do {
            let thumbnailURL = try await ThumbnailGenerator.generateThumbnail(for: destination, outputDir: thumbnailsDirectory)
            thumbnailPath = thumbnailURL.path
        } catch {
            print("Failed to generate thumbnail for \(destination): \(error)")
        }
        
        var duration: Double?
        var width: Int?
        var height: Int?
        
        if fileType == .liveVideo {
            let asset = AVURLAsset(url: destination)
            do {
                let videoDuration = try await asset.load(.duration)
                duration = videoDuration.seconds
                if let track = try await asset.loadTracks(withMediaType: .video).first {
                    let size = try await track.load(.naturalSize)
                    width = Int(size.width)
                    height = Int(size.height)
                }
            } catch {
                print("Failed to load video metadata: \(error)")
            }
        } else {
            if let image = NSImage(contentsOf: destination) {
                width = Int(image.size.width)
                height = Int(image.size.height)
            }
        }
        
        return WallpaperItem(
            title: url.deletingPathExtension().lastPathComponent,
            categoryID: categoryID == "all" ? "nature" : categoryID,
            fileType: fileType,
            localPath: destination.path,
            thumbnailPath: thumbnailPath,
            width: width,
            height: height,
            duration: duration
        )
    }
    
    func saveDownloadedData(_ data: Data, filename: String, title: String) async throws -> (localURL: URL, thumbnailURL: URL) {
        let localURL = wallpapersDirectory.appendingPathComponent(filename)
        try data.write(to: localURL)
        
        let thumbnailURL = try await ThumbnailGenerator.generateThumbnail(for: localURL, outputDir: thumbnailsDirectory)
        return (localURL, thumbnailURL)
    }
    
    func delete(_ item: WallpaperItem) {
        if let localPath = item.localPath {
            try? fileManager.removeItem(atPath: localPath)
        }
        if let thumbnailPath = item.thumbnailPath {
            try? fileManager.removeItem(atPath: thumbnailPath)
        }
    }
}
