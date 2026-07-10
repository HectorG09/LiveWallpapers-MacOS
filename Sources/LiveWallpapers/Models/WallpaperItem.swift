import Foundation
import SwiftData

@Model
final class WallpaperItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryID: String
    var fileTypeRaw: String
    var localPath: String?
    var remoteURL: String?
    var thumbnailPath: String?
    var isFavorite: Bool
    var dateAdded: Date
    var width: Int?
    var height: Int?
    var duration: Double?
    var attribution: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        categoryID: String,
        fileType: WallpaperFileType,
        localPath: String? = nil,
        remoteURL: String? = nil,
        thumbnailPath: String? = nil,
        isFavorite: Bool = false,
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        attribution: String? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.fileTypeRaw = fileType.rawValue
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.thumbnailPath = thumbnailPath
        self.isFavorite = isFavorite
        self.dateAdded = Date()
        self.width = width
        self.height = height
        self.duration = duration
        self.attribution = attribution
    }
    
    var fileType: WallpaperFileType {
        get { WallpaperFileType(rawValue: fileTypeRaw) ?? .staticImage }
        set { fileTypeRaw = newValue.rawValue }
    }
    
    var localURL: URL? {
        guard let localPath else { return nil }
        return URL(fileURLWithPath: localPath)
    }
    
    var thumbnailURL: URL? {
        guard let thumbnailPath else { return nil }
        return URL(fileURLWithPath: thumbnailPath)
    }
    
    var resolvedURL: URL? {
        localURL
    }
}
