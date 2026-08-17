import AVFoundation

/// Plays inaudible audio so iOS keeps the app (and its install server) alive
/// in the background while the system installer downloads a signed IPA.
/// A plain background task only buys ~30s, which is not enough for large apps;
/// the `audio` background mode (declared in Info.plist) keeps the process
/// running for the duration of the download.
@MainActor
final class InstallKeepAlive {
    static let shared = InstallKeepAlive()

    private let engine = AVAudioEngine()
    private lazy var source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in buffers {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        return noErr
    }

    private(set) var isActive = false
    private var sourceAttached = false
    private var watchdog: Task<Void, Never>?

    /// Hard cap so silent audio never plays forever if an install is abandoned.
    private static let maxDuration: TimeInterval = 30 * 60

    func start() {
        guard !isActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            if !sourceAttached {
                engine.attach(source)
                sourceAttached = true
            }
            engine.connect(source, to: engine.mainMixerNode, format: nil)
            engine.mainMixerNode.outputVolume = 0
            try engine.start()
            isActive = true
            watchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.maxDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            isActive = false
            engine.stop()
            engine.disconnectNodeOutput(source)
            try? session.setActive(false)
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        watchdog?.cancel()
        watchdog = nil
        engine.stop()
        engine.disconnectNodeOutput(source)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
