import Foundation

/// Optional online source for sample static wallpapers.
/// Requires a free Unsplash API access key from https://unsplash.com/developers
enum UnsplashService {
    private static let baseURL = URL(string: "https://api.unsplash.com/")!
    
    struct Photo: Codable, Identifiable {
        let id: String
        let width: Int
        let height: Int
        let urls: URLs
        let user: User
        let links: Links
        
        struct URLs: Codable {
            let raw: String
            let full: String
            let regular: String
            let small: String
            let thumb: String
        }
        
        struct User: Codable {
            let name: String
            let links: UserLinks
            
            struct UserLinks: Codable {
                let html: String
            }
        }
        
        struct Links: Codable {
            let html: String
        }
    }
    
    static func fetchCurated(accessKey: String, count: Int = 20) async throws -> [Photo] {
        var components = URLComponents(url: baseURL.appendingPathComponent("photos"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "order_by", value: "popular"),
            URLQueryItem(name: "per_page", value: "\(count)")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UnsplashError.invalidResponse
        }
        
        return try JSONDecoder().decode([Photo].self, from: data)
    }
    
    static func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UnsplashError.invalidResponse
        }
        return data
    }
    
    static func wallpaperItem(from photo: Photo, categoryID: String) -> WallpaperItem {
        WallpaperItem(
            title: "Photo by \(photo.user.name)",
            categoryID: categoryID,
            fileType: .staticImage,
            remoteURL: photo.urls.regular,
            isFavorite: false,
            width: photo.width,
            height: photo.height,
            attribution: "\(photo.user.name) on Unsplash"
        )
    }
}

enum UnsplashError: Error {
    case invalidResponse
    case missingAccessKey
}
