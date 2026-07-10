import Foundation

enum WallpaperFileType: String, Codable, CaseIterable {
    case staticImage = "static"
    case liveVideo = "video"
    case dynamicHeic = "heic"
    
    var displayName: String {
        switch self {
        case .staticImage: return "Static"
        case .liveVideo: return "Live Video"
        case .dynamicHeic: return "Dynamic"
        }
    }
    
    static func infer(from url: URL) -> WallpaperFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "m4v", "avi", "mkv":
            return .liveVideo
        case "heic":
            return .dynamicHeic
        default:
            return .staticImage
        }
    }
}
