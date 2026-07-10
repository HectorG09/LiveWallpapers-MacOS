import AppKit
import AVFoundation
import UniformTypeIdentifiers

enum ThumbnailGenerator {
    private static let thumbnailSize = CGSize(width: 400, height: 400)
    
    static func generateThumbnail(for url: URL, outputDir: URL) async throws -> URL {
        let fileType = WallpaperFileType.infer(from: url)
        let thumbnailName = url.deletingPathExtension().lastPathComponent + "_thumb.jpg"
        let outputURL = outputDir.appendingPathComponent(thumbnailName)
        
        switch fileType {
        case .liveVideo:
            return try await generateVideoThumbnail(url: url, outputURL: outputURL)
        case .staticImage, .dynamicHeic:
            return try await generateImageThumbnail(url: url, outputURL: outputURL)
        }
    }
    
    private static func generateImageThumbnail(url: URL, outputURL: URL) async throws -> URL {
        guard let image = NSImage(contentsOf: url) else {
            throw ThumbnailError.failedToLoadImage
        }
        
        let resized = image.resized(toFit: thumbnailSize)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw ThumbnailError.failedToEncode
        }
        
        try data.write(to: outputURL)
        return outputURL
    }
    
    private static func generateVideoThumbnail(url: URL, outputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = thumbnailSize
        
        let duration = try await asset.load(.duration)
        let time = CMTime(seconds: min(1, duration.seconds * 0.2), preferredTimescale: 600)
        
        let cgImage = try await generator.image(at: time).image
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        let resized = image.resized(toFit: thumbnailSize)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw ThumbnailError.failedToEncode
        }
        
        try data.write(to: outputURL)
        return outputURL
    }
}

enum ThumbnailError: Error {
    case failedToLoadImage
    case failedToEncode
}

extension NSImage {
    func resized(toFit maxSize: CGSize) -> NSImage {
        let originalSize = self.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return self }
        
        let scale = min(maxSize.width / originalSize.width, maxSize.height / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: originalSize),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
