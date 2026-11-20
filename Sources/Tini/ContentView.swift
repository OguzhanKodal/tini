import SwiftUI

let accent = Color(red: 0.40, green: 0.36, blue: 0.96)

struct ContentView: View {
    @Environment(Player.self) private var player
    @State private var dropTargeted = false
    @State private var showRemaining = true

    var body: some View {
        Group {
            if player.hasFile { playerView } else { emptyView }
        }
        .padding(20)
        .frame(width: 440, height: 280)
        .tint(accent)
        .navigationTitle(player.hasFile ? player.title : "Tını")
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first else { return false }
            player.open(u)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted && player.hasFile {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent, lineWidth: 2)
                    .padding(6)
            }
        }
    }

    // MARK: Boş ekran

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(accent)
            Text("Ses dosyasını buraya bırak")
                .font(.headline)
            Button("Dosya seç…") { player.openPanel() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            if let e = player.error {
                Text(e).font(.caption).foregroundStyle(.red)
            } else {
                Text("mp3 · m4a · wav · aiff · flac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(dropTargeted ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary))
        }
    }

    // MARK: Oynatıcı

    private var playerView: some View {
        VStack(spacing: 0) {
            WaveformView(
                peaks: player.peaks,
                progress: player.duration > 0 ? player.current / player.duration : 0,
                loop: loopFractions,
                loopStartOnly: player.loopB == nil ? player.loopA.map { $0 / player.duration } : nil
            ) { player.seek(to: $0 * player.duration) }
            .frame(height: 64)

            HStack {
                Text(timeString(player.current))
                Spacer()
                Text(rightTime)
                    .onTapGesture { showRemaining.toggle() }
                    .help(showRemaining ? "Bu hızda kalan süre" : "Toplam süre")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.top, 6)

            HStack(spacing: 30) {
                IconButton(symbol: "gobackward.5", size: 18) { player.skip(-Player.skip) }
                    .help("5 sn geri (←)")
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(accent))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Oynat / Duraklat (boşluk)")
                IconButton(symbol: "goforward.5", size: 18) { player.skip(Player.skip) }
                    .help("5 sn ileri (→)")
            }
            .padding(.top, 4)

            Spacer(minLength: 14)

            speedRow
            HStack(spacing: 10) {
                pitchControl
                Spacer()
                loopButton
                IconButton(symbol: "folder", size: 13) { player.openPanel() }
                    .help("Başka dosya aç (⌘O)")
            }
            .padding(.top, 12)
        }
    }

    private var speedRow: some View {
        let rate = Binding(get: { player.rate }, set: { player.rate = ($0 * 20).rounded() / 20 })
        return HStack(spacing: 10) {
            Image(systemName: "tortoise").foregroundStyle(.secondary)
            Slider(value: rate, in: Player.rateRange)
                .controlSize(.small)
            Image(systemName: "hare").foregroundStyle(.secondary)
            Menu {
                ForEach(Player.ratePresets, id: \.self) { r in
                    Button(rateString(r)) { player.rate = r }
                }
            } label: {
                Text(rateString(player.rate))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(player.rate == 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(accent))
                    .frame(width: 52)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.quaternary.opacity(0.6)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Hız (↑ ↓, 0 = normal)")
        }
    }

    private var pitchControl: some View {
        HStack(spacing: 2) {
            Text("Ton").font(.caption).foregroundStyle(.secondary).padding(.trailing, 4)
            IconButton(symbol: "minus", size: 10) { player.pitch -= 1 }
            Text(player.pitch == 0 ? "0" : String(format: "%+d", player.pitch))
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(player.pitch == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(accent))
                .frame(width: 28)
                .onTapGesture { player.pitch = 0 }
            IconButton(symbol: "plus", size: 10) { player.pitch += 1 }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(.quaternary.opacity(0.6)))
        .help("Ton, yarım ses (hızdan bağımsız). Sayıya tıkla: sıfırla")
    }

    private var loopButton: some View {
        let label: String
        if player.loopActive { label = "A–B" } else if player.loopA != nil { label = "A–…" } else { label = "A–B" }
        return Button { player.loopTap() } label: {
            HStack(spacing: 4) {
                Image(systemName: "repeat").font(.system(size: 11, weight: .semibold))
                Text(label).font(.callout.weight(.medium))
            }
            .foregroundStyle(player.loopActive ? AnyShapeStyle(.white) : player.loopA != nil ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(player.loopActive ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary.opacity(0.6))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(player.loopActive ? "Döngüyü kapat (L)" : player.loopA != nil ? "Bitiş noktasını işaretle (L)" : "Bölüm tekrarı: başlangıcı işaretle (L)")
    }

    private var loopFractions: ClosedRange<Double>? {
        guard let a = player.loopA, let b = player.loopB, player.duration > 0 else { return nil }
        return (a / player.duration)...(b / player.duration)
    }

    private var rightTime: String {
        if showRemaining {
            return "−" + timeString(max(player.duration - player.current, 0) / player.rate)
        }
        return timeString(player.duration)
    }
}

struct IconButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(hover ? .primary : .secondary)
                .frame(width: size + 14, height: size + 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct WaveformView: View {
    let peaks: [Float]
    let progress: Double
    let loop: ClosedRange<Double>?
    let loopStartOnly: Double?
    let onSeek: (Double) -> Void
    @State private var scrub: Double?
    @State private var hoverX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Canvas { ctx, size in
                let p = scrub ?? progress
                if let l = loop {
                    let r = CGRect(x: l.lowerBound * size.width, y: 0,
                                   width: (l.upperBound - l.lowerBound) * size.width, height: size.height)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(accent.opacity(0.13)))
                }
                let bar: CGFloat = 2, gap: CGFloat = 1.6
                let count = max(Int(size.width / (bar + gap)), 1)
                let bars = resample(count)
                for i in 0..<count {
                    let x = CGFloat(i) * (bar + gap)
                    let h = max(CGFloat(bars[i]) * size.height, 2)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: bar, height: h)
                    let played = Double(x + bar / 2) / Double(size.width) <= p
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(played ? accent : .primary.opacity(0.18)))
                }
                for f in [loop?.lowerBound, loop?.upperBound, loopStartOnly].compactMap({ $0 }) {
                    let x = f * size.width
                    ctx.fill(Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(accent))
                }
                if let hx = hoverX, scrub == nil {
                    ctx.fill(Path(CGRect(x: hx - 0.5, y: 0, width: 1, height: size.height)),
                             with: .color(.primary.opacity(0.3)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { scrub = min(max($0.location.x / w, 0), 1) }
                    .onEnded {
                        onSeek(min(max($0.location.x / w, 0), 1))
                        scrub = nil
                    }
            )
            .onContinuousHover { phase in
                if case .active(let pt) = phase { hoverX = pt.x } else { hoverX = nil }
            }
        }
    }

    private func resample(_ n: Int) -> [Float] {
        guard !peaks.isEmpty else { return Array(repeating: 0, count: n) }
        return (0..<n).map { i in
            let lo = i * peaks.count / n
            let hi = max((i + 1) * peaks.count / n, lo + 1)
            return peaks[lo..<min(hi, peaks.count)].max() ?? 0
        }
    }
}

func timeString(_ t: Double) -> String {
    let s = Int(t.rounded(.down))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

func rateString(_ r: Double) -> String {
    var s = String(format: "%.2f", r)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s.replacingOccurrences(of: ".", with: ",") + "×"
}
