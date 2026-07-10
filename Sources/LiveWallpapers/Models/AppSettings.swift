import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: String = "default"
    
    // Energy
    var pauseOnBattery: Bool = true
    var pauseOnLowPower: Bool = true
    var pauseOnThermalPressure: Bool = true
    var pauseWhenFullscreenApp: Bool = true
    var fallbackToStaticOnBattery: Bool = false
    
    // Auto change
    var autoChangeEnabled: Bool = false
    var autoChangeIntervalSeconds: Double = 300 // 5 minutes
    var autoChangeOnlyOnAC: Bool = true
    
    // Display
    var applyToAllDisplays: Bool = true
    
    // Online source
    var unsplashEnabled: Bool = false
    var unsplashAccessKey: String = ""
    
    init() {}
}
