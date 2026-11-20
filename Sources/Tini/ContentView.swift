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
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
        .frame(width: 440, height: 286)
        .background {
            // Başlık çubuğu gizli: zemin ve dosya adı onun altına da uzanır.
            ZStack(alignment: .top) {
                Backdrop(active: player.isPlaying)
                titleBar
            }
            .ignoresSafeArea()
        }
        .tint(accent)
        .containerBackground(.thinMaterial, for: .window)
        .navigationTitle(player.hasFile ? player.title : "Tını")
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first else { return false }
            player.open(u)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted && player.hasFile {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(accent, lineWidth: 2)
                    .padding(6)
                    .ignoresSafeArea()
            }
        }
    }

    /// Başlık çubuğu gizli: trafik ışıklarının hizasında dosya adı.
    private var titleBar: some View {
        Text(player.hasFile ? player.title : "Tını")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 84)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
    }

    // MARK: Boş ekran

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, isActive: dropTargeted)
            Text("Ses dosyasını buraya bırak")
                .font(.headline)
            Button("Dosya seç…") { player.openPanel() }
                .buttonStyle(.glassProminent)
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
        .glassEffect(dropTargeted ? .regular.tint(accent.opacity(0.25)) : .regular,
                     in: .rect(cornerRadius: 24))
        .animation(.smooth, value: dropTargeted)
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
            .frame(height: 62)

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

            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 22) {
                    GlassIcon(symbol: "gobackward.5", size: 16, diameter: 40) { player.skip(-Player.skip) }
                        .help("5 sn geri (←)")
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(accent).interactive(), in: .circle)
                    .help("Oynat / Duraklat (boşluk)")
                    GlassIcon(symbol: "goforward.5", size: 16, diameter: 40) { player.skip(Player.skip) }
                        .help("5 sn ileri (→)")
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 12)

            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    speedBar
                    HStack(spacing: 10) {
                        pitchControl
                        Spacer()
                        loopButton
                        GlassIcon(symbol: "folder", size: 13, diameter: 34) { player.openPanel() }
                            .help("Başka dosya aç (⌘O)")
                    }
                }
            }
        }
    }

    private var speedBar: some View {
        let rate = Binding(get: { player.rate }, set: { player.rate = ($0 * 20).rounded() / 20 })
        return HStack(spacing: 10) {
            Image(systemName: "tortoise").foregroundStyle(.secondary)
            Slider(value: rate, in: Player.rateRange)
                .controlSize(.small)
            Image(systemName: "hare").foregroundStyle(.secondary)
            HStack(spacing: 0) {
                PlainIcon(symbol: "minus", size: 10) { player.nudgeRate(-Player.rateStep) }
                    .help("0,05 yavaşlat (↓)")
                Menu {
                    ForEach(Player.ratePresets, id: \.self) { r in
                        Toggle(rateString(r), isOn: Binding(
                            get: { abs(player.rate - r) < 0.001 },
                            set: { _ in player.rate = r }))
                        if r == 1 || r == 1.5 { Divider() }
                    }
                } label: {
                    Text(rateString(player.rate))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(player.rate == 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(accent))
                        .frame(width: 50)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Hız: değere tıkla → liste (0 = normal hız)")
                PlainIcon(symbol: "plus", size: 10) { player.nudgeRate(Player.rateStep) }
                    .help("0,05 hızlandır (↑)")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 38)
        .glassEffect(.regular, in: .capsule)
    }

    private var pitchControl: some View {
        HStack(spacing: 2) {
            Text("Ton").font(.caption).foregroundStyle(.secondary).padding(.trailing, 4)
            PlainIcon(symbol: "minus", size: 10) { player.pitch -= 1 }
            Text(player.pitch == 0 ? "0" : String(format: "%+d", player.pitch))
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(player.pitch == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(accent))
                .frame(width: 28)
                .contentTransition(.numericText(value: Double(player.pitch)))
                .onTapGesture { player.pitch = 0 }
            PlainIcon(symbol: "plus", size: 10) { player.pitch += 1 }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 34)
        .glassEffect(.regular, in: .capsule)
        .help("Ton, yarım ses (hızdan bağımsız). Sayıya tıkla: sıfırla")
    }

    private var loopButton: some View {
        Button { player.loopTap() } label: {
            HStack(spacing: 4) {
                Image(systemName: "repeat").font(.system(size: 11, weight: .semibold))
                Text(player.loopA != nil && !player.loopActive ? "A–…" : "A–B")
                    .font(.callout.weight(.medium))
            }
            .foregroundStyle(player.loopActive ? AnyShapeStyle(.white)
                             : player.loopA != nil ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(player.loopActive ? .regular.tint(accent).interactive() : .regular.interactive(),
                     in: .capsule)
        .help(player.loopActive ? "Döngüyü kapat (L)"
              : player.loopA != nil ? "Bitiş noktasını işaretle (L)" : "Bölüm tekrarı: başlangıcı işaretle (L)")
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

/// Camın kırılacağı renkli zemin: pencerenin arkasındaki bulanık renge mor bir ışık katar.
struct Backdrop: View {
    let active: Bool

    var body: some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(active ? 0.38 : 0.24), .clear],
                           center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: 230)
            RadialGradient(colors: [Color(red: 0.75, green: 0.45, blue: 1).opacity(0.18), .clear],
                           center: UnitPoint(x: 0.08, y: 1), startRadius: 0, endRadius: 220)
            RadialGradient(colors: [Color(red: 0.3, green: 0.6, blue: 1).opacity(0.14), .clear],
                           center: UnitPoint(x: 0.95, y: 0.05), startRadius: 0, endRadius: 220)
        }
        .animation(.smooth(duration: 0.8), value: active)
        .allowsHitTesting(false)
    }
}

/// Cam daire içinde simge düğme.
struct GlassIcon: View {
    let symbol: String
    let size: CGFloat
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

/// Cam kapsülün içinde kullanılan çerçevesiz simge düğme.
struct PlainIcon: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hover ? .primary : .secondary)
                .frame(width: size + 16, height: size + 16)
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
                    ctx.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(accent.opacity(0.16)))
                }
                let bar: CGFloat = 2.2, gap: CGFloat = 1.6
                let count = max(Int(size.width / (bar + gap)), 1)
                let bars = resample(count)
                for i in 0..<count {
                    let x = CGFloat(i) * (bar + gap)
                    let h = max(CGFloat(bars[i]) * size.height, 2.2)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: bar, height: h)
                    let played = Double(x + bar / 2) / Double(size.width) <= p
                    ctx.fill(Path(roundedRect: rect, cornerRadius: bar / 2),
                             with: .color(played ? accent : .primary.opacity(0.2)))
                }
                for f in [loop?.lowerBound, loop?.upperBound, loopStartOnly].compactMap({ $0 }) {
                    let x = f * size.width
                    ctx.fill(Path(roundedRect: CGRect(x: x - 1, y: 0, width: 2, height: size.height), cornerRadius: 1),
                             with: .color(accent))
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
    String(format: "%.2f", r).replacingOccurrences(of: ".", with: ",") + "×"
}
