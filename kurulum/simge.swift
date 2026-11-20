// Tını uygulama simgesini çizer: swift simge.swift <çıktı.png>
import AppKit

let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 100, dy: 100)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(red: 0.33, green: 0.28, blue: 0.90, alpha: 1),
                    NSColor(red: 0.58, green: 0.40, blue: 0.98, alpha: 1)])!.draw(in: path, angle: 60)
// Dalga: ortası yüksek, kenarlara doğru alçalan yuvarlak çubuklar
let heights: [Double] = [0.16, 0.30, 0.52, 0.38, 0.72, 0.95, 0.62, 0.84, 0.46, 0.28, 0.18]
let bar = 38.0, gap = 26.0
let total = Double(heights.count) * bar + Double(heights.count - 1) * gap
var x = (size - total) / 2
NSColor(white: 1, alpha: 0.96).setFill()
for h in heights {
    let hh = max(h * 470, bar)
    NSBezierPath(roundedRect: NSRect(x: x, y: (size - hh) / 2, width: bar, height: hh),
                 xRadius: bar / 2, yRadius: bar / 2).fill()
    x += bar + gap
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
