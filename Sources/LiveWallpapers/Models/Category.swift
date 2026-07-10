import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var sortOrder: Int
    var isBuiltIn: Bool
    
    init(id: String, name: String, icon: String, sortOrder: Int, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }
}

extension Category {
    @MainActor
    static let builtIn: [Category] = [
        Category(id: "all", name: "All Wallpapers", icon: "square.grid.2x2", sortOrder: 0, isBuiltIn: true),
        Category(id: "favorites", name: "Favorites", icon: "heart.fill", sortOrder: 1, isBuiltIn: true),
        Category(id: "nature", name: "Nature", icon: "leaf", sortOrder: 2, isBuiltIn: true),
        Category(id: "abstract", name: "Abstract", icon: "swirl.circle.righthalf.filled", sortOrder: 3, isBuiltIn: true),
        Category(id: "city", name: "City", icon: "building.2", sortOrder: 4, isBuiltIn: true),
        Category(id: "animals", name: "Animals", icon: "pawprint", sortOrder: 5, isBuiltIn: true),
        Category(id: "space", name: "Space", icon: "moon.stars", sortOrder: 6, isBuiltIn: true),
        Category(id: "minimal", name: "Minimal", icon: "minus", sortOrder: 7, isBuiltIn: true),
        Category(id: "dark", name: "Dark", icon: "moon.fill", sortOrder: 8, isBuiltIn: true),
        Category(id: "live", name: "Live", icon: "play.rectangle.fill", sortOrder: 9, isBuiltIn: true)
    ]
}
