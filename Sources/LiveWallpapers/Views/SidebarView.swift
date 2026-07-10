import SwiftUI

struct SidebarView: View {
    let categories: [Category]
    @Binding var selectedCategoryID: String
    
    var body: some View {
        List(selection: $selectedCategoryID) {
            Section("Categories") {
                ForEach(categories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Live Wallpapers")
    }
}
