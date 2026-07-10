import SwiftUI
import SwiftData

struct AddFromURLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var urlString: String = ""
    @State private var status: String = ""
    @State private var isLoading: Bool = false
    @State private var categoryID: String = "nature"
    
    let categories: [Category]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add from URL")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Paste a direct link to a file. Supported: MP4, MOV, JPG, PNG, HEIC.")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            TextField("https://example.com/wallpaper.mp4", text: $urlString)
                .textFieldStyle(.roundedBorder)
            
            Picker("Category", selection: $categoryID) {
                ForEach(categories.filter { !$0.isBuiltIn || ($0.id != "all" && $0.id != "favorites" && $0.id != "live") }.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.menu)
            
            if !status.isEmpty {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(status.contains("Error") ? .red : .secondary)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button {
                    download()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Download")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.isEmpty || isLoading || !URLDownloadService.isDirectFileURL(urlString))
            }
        }
        .padding()
        .frame(width: 450)
    }
    
    private func download() {
        guard URLDownloadService.isDirectFileURL(urlString) else {
            status = "Error: URL must point directly to a supported file."
            return
        }
        
        isLoading = true
        status = "Downloading..."
        
        Task {
            do {
                let result = try await URLDownloadService.download(urlString: urlString)
                let item = WallpaperItem(
                    title: result.title,
                    categoryID: categoryID,
                    fileType: result.fileType,
                    localPath: result.localURL.path,
                    thumbnailPath: result.thumbnailURL.path
                )
                
                await MainActor.run {
                    modelContext.insert(item)
                    try? modelContext.save()
                    status = "Added: \(result.title)"
                    urlString = ""
                    isLoading = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    status = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
