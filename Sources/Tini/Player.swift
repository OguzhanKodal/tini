import AppKit
import AVFoundation
import MediaPlayer
import Observation
import UniformTypeIdentifiers

/// Ses motoru: AVAudioPlayerNode → AVAudioUnitTimePitch → mikser.
/// Hız değişince ton korunur; ton ayrıca yarım ton olarak kaydırılabilir.
@MainActor @Observable
final class Player {
    static let shared = Player()

    private(set) var url: URL?
    private(set) var title = ""
    private(set) var duration: Double = 0
    private(set) var current: Double = 0
    private(set) var isPlaying = false
    private(set) var peaks: [Float] = []
    private(set) var error: String?
    private(set) var loopA: Double?
    private(set) var loopB: Double?

    var rate: Double = Player.savedRate {
        didSet {
            let r = min(max(rate, Self.rateRange.lowerBound), Self.rateRange.upperBound)
            if r != rate { rate = r; return }
            timePitch.rate = Float(rate)
            UserDefaults.standard.set(rate, forKey: "rate")
            updateNowPlaying()
        }
    }

    var pitch: Int = 0 {
        didSet {
            let p = min(max(pitch, -12), 12)
            if p != pitch { pitch = p; return }
            timePitch.pitch = Float(pitch * 100)
        }
    }

    static let rateRange = 0.25...2.0
    /// 0,50 – 1,50 arası her 0,05, ardından 1,75 ve 2.
    static let ratePresets: [Double] = (10...30).map { Double($0 * 5) / 100 } + [1.75, 2]
    static let rateStep = 0.05
    static let skip: Double = 5

    var loopActive: Bool { loopA != nil && loopB != nil }
    var hasFile: Bool { url != nil }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let node = AVAudioPlayerNode()
    @ObservationIgnored private let timePitch = AVAudioUnitTimePitch()
    @ObservationIgnored private var file: AVAudioFile?
    @ObservationIgnored private var sampleRate: Double = 44_100
    @ObservationIgnored private var segmentStart: AVAudioFramePosition = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var timer: Timer?

    private static var savedRate: Double {
        let r = UserDefaults.standard.double(forKey: "rate")
        return r == 0 ? 1 : min(max(r, rateRange.lowerBound), rateRange.upperBound)
    }

    private init() {
        engine.attach(node)
        engine.attach(timePitch)
        timePitch.rate = Float(rate)
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.engineConfigurationChanged() }
        }
        setupRemoteCommands()
    }

    // MARK: Dosya

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.prompt = "Aç"
        if panel.runModal() == .OK, let u = panel.url { open(u) }
    }

    func open(_ url: URL) {
        let f: AVAudioFile
        do {
            f = try AVAudioFile(forReading: url)
        } catch {
            self.error = "Bu dosya açılamadı: \(url.lastPathComponent)"
            return
        }
        guard f.length > 0 else {
            self.error = "Dosya boş görünüyor: \(url.lastPathComponent)"
            return
        }
        error = nil
        generation += 1
        node.stop()
        engine.stop()

        file = f
        self.url = url
        title = url.deletingPathExtension().lastPathComponent
        sampleRate = f.processingFormat.sampleRate
        duration = Double(f.length) / sampleRate
        current = 0
        loopA = nil
        loopB = nil
        peaks = []

        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(timePitch)
        engine.connect(node, to: timePitch, format: f.processingFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: f.processingFormat)
        engine.prepare()
        do { try engine.start() } catch {
            self.error = "Ses çıkışı başlatılamadı."
            return
        }

        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        loadPeaks(for: url)
        schedule(from: 0)
        play()
    }

    private func loadPeaks(for url: URL) {
        Task.detached(priority: .userInitiated) {
            let p = Waveform.peaks(of: url, buckets: 1200)
            await MainActor.run {
                if Player.shared.url == url { Player.shared.peaks = p }
            }
        }
    }

    // MARK: Oynatma

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard file != nil, !isPlaying else { return }
        if !engine.isRunning { try? engine.start() }
        node.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        current = position()
        node.pause()
        isPlaying = false
        stopTimer()
        updateNowPlaying()
    }

    func seek(to t: Double) {
        guard file != nil else { return }
        current = min(max(t, 0), duration)
        schedule(from: current)
        if isPlaying { node.play() }
        updateNowPlaying()
    }

    func skip(_ delta: Double) { seek(to: position() + delta) }

    func nudgeRate(_ delta: Double) { rate = ((rate + delta) * 100).rounded() / 100 }

    /// Birinci basış A'yı, ikinci basış B'yi işaretler (döngü başlar), üçüncüsü döngüyü kaldırır.
    func loopTap() {
        guard file != nil else { return }
        let t = position()
        if let a = loopA, loopB == nil {
            if t > a + 0.2 { loopB = t } else { loopA = t; return }
            seek(to: a)
        } else if loopA == nil {
            loopA = t
        } else {
            clearLoop()
        }
    }

    func clearLoop() {
        guard loopA != nil else { return }
        loopA = nil
        loopB = nil
        seek(to: position())
    }

    /// Şu anki konum (saniye).
    func position() -> Double {
        guard isPlaying,
              let nodeTime = node.lastRenderTime,
              let pt = node.playerTime(forNodeTime: nodeTime)
        else { return current }
        return min(max(Double(segmentStart + pt.sampleTime) / sampleRate, 0), duration)
    }

    private func frame(_ t: Double) -> AVAudioFramePosition {
        AVAudioFramePosition((t * sampleRate).rounded())
    }

    private func schedule(from t: Double) {
        guard let file else { return }
        generation += 1
        let gen = generation
        node.stop()

        var start = min(max(frame(t), 0), file.length)
        var end = file.length
        if let a = loopA, let b = loopB {
            let fa = frame(a), fb = frame(b)
            if start >= fb { start = fa }
            end = fb
        }
        segmentStart = start
        let count = AVAudioFrameCount(max(end - start, 0))
        guard count > 0 else {
            if isPlaying { finished(gen) }
            return
        }
        node.scheduleSegment(file, startingFrame: start, frameCount: count, at: nil,
                             completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.finished(gen) }
        }
    }

    private func finished(_ gen: Int) {
        guard gen == generation else { return }
        if let a = loopA, loopB != nil {
            schedule(from: a)
            if isPlaying { node.play() }
            return
        }
        isPlaying = false
        stopTimer()
        current = 0
        schedule(from: 0)
        updateNowPlaying()
    }

    private func engineConfigurationChanged() {
        guard file != nil else { return }
        let t = position()
        let was = isPlaying
        isPlaying = false
        try? engine.start()
        current = t
        schedule(from: t)
        if was { play() }
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { _ in
            MainActor.assumeIsolated {
                let p = Player.shared
                if p.isPlaying { p.current = p.position() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Klavyedeki medya tuşları ve Denetim Merkezi

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        func on(_ cmd: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
            cmd.isEnabled = true
            cmd.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
        }
        on(c.togglePlayPauseCommand) { Player.shared.togglePlay() }
        on(c.playCommand) { Player.shared.play() }
        on(c.pauseCommand) { Player.shared.pause() }
        c.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skip)]
        c.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skip)]
        on(c.skipForwardCommand) { Player.shared.skip(Player.skip) }
        on(c.skipBackwardCommand) { Player.shared.skip(-Player.skip) }
        c.changePlaybackPositionCommand.isEnabled = true
        c.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let t = e.positionTime
            Task { @MainActor in Player.shared.seek(to: t) }
            return .success
        }
    }

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard file != nil else {
            center.nowPlayingInfo = nil
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position(),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        center.playbackState = isPlaying ? .playing : .paused
    }
}

/// Dalga biçimi için kaba ses yüksekliği (RMS) değerleri.
enum Waveform {
    static func peaks(of url: URL, buckets: Int) -> [Float] {
        guard let f = try? AVAudioFile(forReading: url), f.length > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: 1 << 16)
        else { return [] }
        let total = Double(f.length)
        let channels = Int(f.processingFormat.channelCount)
        var sums = [Float](repeating: 0, count: buckets)
        var counts = [Int](repeating: 0, count: buckets)
        var pos = 0
        while true {
            do { try f.read(into: buf) } catch { break }
            let n = Int(buf.frameLength)
            guard n > 0, let data = buf.floatChannelData else { break }
            var i = 0
            while i < n {
                var s: Float = 0
                for c in 0..<channels { s = max(s, abs(data[c][i])) }
                let b = min(Int(Double(pos + i) / total * Double(buckets)), buckets - 1)
                sums[b] += s * s
                counts[b] += 1
                i += 2
            }
            pos += n
        }
        var out = (0..<buckets).map { counts[$0] > 0 ? (sums[$0] / Float(counts[$0])).squareRoot() : 0 }
        let top = out.max() ?? 0
        if top > 0 { out = out.map { pow($0 / top, 0.8) } }
        return out
    }
}
