import AppKit
import AVFoundation
import Combine

final class WallpaperWindowController: NSWindowController {
    private let queuePlayer = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    private var currentVideoURL: URL?
    private var displayObserver: AnyCancellable?
    
    init(screen: NSScreen) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        super.init(window: window)
        configureWindow(window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        window.level = NSWindow.Level(rawValue: desktopIconLevel - 1)
        
        // Show the window behind everything else at the desktop level.
        window.order(.below, relativeTo: 0)
    }
    
    func setVideo(url: URL, fillMode: VideoFillMode = .aspectFill) {
        guard currentVideoURL != url else { return }
        currentVideoURL = url
        
        stopVideo()
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        if let playerView = window?.contentView as? PlayerView {
            playerView.player = queuePlayer
            playerView.fillMode = fillMode
        } else {
            let playerView = PlayerView(player: queuePlayer, fillMode: fillMode)
            window?.contentView = playerView
        }
        
        queuePlayer.play()
    }
    
    func stopVideo() {
        queuePlayer.pause()
        playerLooper?.disableLooping()
        playerLooper = nil
        queuePlayer.removeAllItems()
        currentVideoURL = nil
    }
    
    func play() {
        guard currentVideoURL != nil else { return }
        queuePlayer.play()
    }
    
    func pause() {
        queuePlayer.pause()
    }
    
    func setPaused(_ paused: Bool) {
        paused ? pause() : play()
    }
    
    func updateFrame(_ frame: NSRect) {
        window?.setFrame(frame, display: true)
    }
}

enum VideoFillMode {
    case aspectFill
    case aspectFit
    case stretch
    
    var avGravity: AVLayerVideoGravity {
        switch self {
        case .aspectFill: return .resizeAspectFill
        case .aspectFit: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

final class PlayerView: NSView {
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    var fillMode: VideoFillMode = .aspectFill {
        didSet { playerLayer.videoGravity = fillMode.avGravity }
    }
    
    init(player: AVPlayer? = nil, fillMode: VideoFillMode = .aspectFill) {
        self.fillMode = fillMode
        super.init(frame: .zero)
        wantsLayer = true
        self.player = player
        playerLayer.videoGravity = fillMode.avGravity
        playerLayer.backgroundColor = NSColor.black.cgColor
        autoresizingMask = [.width, .height]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }
}
