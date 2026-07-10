import Foundation
import AppKit
import IOKit.ps
import Combine

@MainActor
final class EnergyManager: ObservableObject {
    static let shared = EnergyManager()
    
    @Published var isOnBattery: Bool = false
    @Published var isLowPowerMode: Bool = false
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var shouldPauseVideo: Bool = false
    @Published var settings: AppSettings?
    
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()
    private var fullscreenCheckTimer: Timer?
    
    private let shouldPausePublisher = PassthroughSubject<Bool, Never>()
    var shouldPauseVideoPublisher: AnyPublisher<Bool, Never> {
        shouldPausePublisher.eraseToAnyPublisher()
    }
    
    private init() {
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.thermalState = ProcessInfo.processInfo.thermalState
        self.isOnBattery = Self.currentPowerSourceIsBattery()
        updateShouldPause()
    }
    
    func configure(with settings: AppSettings) {
        self.settings = settings
        updateShouldPause()
    }
    
    func startMonitoring() {
        registerPowerSourceNotifications()
        registerProcessInfoNotifications()
        registerWorkspaceNotifications()
        registerScreensaverNotifications()
        startFullscreenAppMonitoring()
    }
    
    func stopMonitoring() {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSourceRunLoopSource = nil
        }
        fullscreenCheckTimer?.invalidate()
        fullscreenCheckTimer = nil
        cancellables.removeAll()
    }
    
    // MARK: - Power Source (IOKit)
    
    private static func currentPowerSourceIsBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, firstSource)?.takeUnretainedValue() as? [String: Any]
        else {
            return false
        }
        return description[kIOPSPowerSourceStateKey as String] as? String == kIOPSBatteryPowerValue
    }
    
    private func registerPowerSourceNotifications() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<EnergyManager>.fromOpaque(ctx).takeUnretainedValue().powerSourceChanged()
        }, context)?.takeRetainedValue() else { return }
        
        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
    
    @objc private func powerSourceChanged() {
        isOnBattery = Self.currentPowerSourceIsBattery()
        updateShouldPause()
    }
    
    // MARK: - Low Power / Thermal
    
    private func registerProcessInfoNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.updateShouldPause()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.updateShouldPause()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sleep / Wake
    
    private func registerWorkspaceNotifications() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        workspaceCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in self?.updateShouldPause() }
            .store(in: &cancellables)
        
        workspaceCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in self?.updateShouldPause() }
            .store(in: &cancellables)
        
        workspaceCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in self?.forcePause(true) }
            .store(in: &cancellables)
        
        workspaceCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in self?.updateShouldPause() }
            .store(in: &cancellables)
    }
    
    // MARK: - Screensaver (private notifications, best-effort)
    
    private func registerScreensaverNotifications() {
        let didStart = Notification.Name("com.apple.screensaver.didstart")
        let didStop = Notification.Name("com.apple.screensaver.didstop")
        
        NotificationCenter.default.publisher(for: didStart)
            .sink { [weak self] _ in self?.forcePause(true) }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: didStop)
            .sink { [weak self] _ in self?.updateShouldPause() }
            .store(in: &cancellables)
    }
    
    // MARK: - Fullscreen App Detection
    
    private func startFullscreenAppMonitoring() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        workspaceCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.checkFullscreenApps() }
            .store(in: &cancellables)
        
        workspaceCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in self?.checkFullscreenApps() }
            .store(in: &cancellables)
        
        // Periodic fallback check
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreenApps()
            }
        }
    }
    
    private func checkFullscreenApps() {
        Task.detached(priority: .utility) { [weak self] in
            let hasFullscreen = await Self.detectFullscreenAppOnAnyScreen()
            await MainActor.run {
                self?.fullscreenAppDetected = hasFullscreen
                self?.updateShouldPause()
            }
        }
    }
    
    private nonisolated static func detectFullscreenAppOnAnyScreen() async -> Bool {
        let (screens, frontApp) = await MainActor.run {
            (NSScreen.screens.map { $0.frame }, NSWorkspace.shared.frontmostApplication)
        }
        guard let frontApp else { return false }
        
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let appWindows = windowList.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == frontApp.processIdentifier }
        
        return appWindows.contains { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { return false }
            
            let rect = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            return screens.contains { screenFrame in
                abs(rect.minX - screenFrame.minX) < 2 &&
                abs(rect.minY - screenFrame.minY) < 2 &&
                abs(rect.width - screenFrame.width) < 2 &&
                abs(rect.height - screenFrame.height) < 2
            }
        }
    }
    
    @Published private var fullscreenAppDetected: Bool = false
    @Published private var forcePaused: Bool = false
    
    private func forcePause(_ pause: Bool) {
        forcePaused = pause
        updateShouldPause()
    }
    
    func updateShouldPause() {
        let pauseOnBattery = settings?.pauseOnBattery ?? true
        let pauseOnLowPower = settings?.pauseOnLowPower ?? true
        let pauseOnThermal = settings?.pauseOnThermalPressure ?? true
        let pauseOnFullscreen = settings?.pauseWhenFullscreenApp ?? true
        
        let shouldPause = forcePaused ||
            (isOnBattery && pauseOnBattery) ||
            (isLowPowerMode && pauseOnLowPower) ||
            ((thermalState == .serious || thermalState == .critical) && pauseOnThermal) ||
            (fullscreenAppDetected && pauseOnFullscreen)
        
        if shouldPause != shouldPauseVideo {
            shouldPauseVideo = shouldPause
            shouldPausePublisher.send(shouldPause)
        }
    }
}


