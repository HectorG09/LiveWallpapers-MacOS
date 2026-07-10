import Foundation

/// Hides/shows desktop icons by toggling Finder's CreateDesktop default.
/// Does not delete any files; it only changes Finder's rendering.
enum DesktopCleanerService {
    static func setDesktopIconsVisible(_ visible: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", visible ? "true" : "false"]
        
        do {
            try task.run()
            task.waitUntilExit()
            restartFinder()
        } catch {
            print("Failed to toggle desktop icons: \(error)")
        }
    }
    
    private static func restartFinder() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Finder"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to restart Finder: \(error)")
        }
    }
    
    static var areDesktopIconsVisible: Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.finder", "CreateDesktop"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "1" || output.lowercased() == "true"
            }
        } catch {
            print("Failed to read desktop visibility: \(error)")
        }
        return true
    }
}
