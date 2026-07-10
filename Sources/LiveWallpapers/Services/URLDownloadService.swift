import Foundation

/// Generic downloader for direct links to image/video files.
/// This only handles URLs that point directly to a file (e.g. ending in .mp4, .mov, .jpg).
/// It does NOT scrape web pages or parse custom URL schemes.
enum URLDownloadService {
    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "jpg", "jpeg", "png", "heic", "heif", "webp"]
    
    struct DownloadResult {
        let localURL: URL
        let thumbnailURL: URL
        let title: String
        let fileType: WallpaperFileType
    }
    
    static func isDirectFileURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let ext = url.pathExtension.lowercased() as String? else {
            return false
        }
        return supportedExtensions.contains(ext)
    }
    
    static func download(urlString: String) async throws -> DownloadResult {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw URLError(.badURL)
        }
        
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw DownloadError.unsupportedFileType(ext)
        }
        
        let fileType = WallpaperFileType.infer(from: url)
        let title = url.deletingPathExtension().lastPathComponent
        let filename = "\(title)_\(UUID().uuidString.prefix(8)).\(ext)"
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse
        }
        
        let (wallpapersDir, thumbnailsDir) = await MainActor.run {
            (ImportService.shared.wallpapersDirectory, ImportService.shared.thumbnailsDirectory)
        }
        let localURL = wallpapersDir.appendingPathComponent(filename)
        try data.write(to: localURL)
        let thumbnailURL = try await ThumbnailGenerator.generateThumbnail(for: localURL, outputDir: thumbnailsDir)
        
        return DownloadResult(
            localURL: localURL,
            thumbnailURL: thumbnailURL,
            title: title,
            fileType: fileType
        )
    }
}

enum DownloadError: Error {
    case unsupportedFileType(String)
    case invalidResponse
}
