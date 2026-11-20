import AppKit
import SwiftUI

@main
struct TiniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Tını", id: "main") {
            ContentView()
                .environment(Player.shared)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Tını Hakkında") { showAbout() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Aç…") { Player.shared.openPanel() }
                    .keyboardShortcut("o")
            }
            CommandMenu("Oynat") {
                Button("Oynat / Duraklat") { Player.shared.togglePlay() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("5 sn Geri") { Player.shared.skip(-Player.skip) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("5 sn İleri") { Player.shared.skip(Player.skip) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Divider()
                Button("Hızlandır") { Player.shared.nudgeRate(0.05) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Yavaşlat") { Player.shared.nudgeRate(-0.05) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Normal Hız") { Player.shared.rate = 1 }
                    .keyboardShortcut("0", modifiers: [])
                Divider()
                Button("A–B Döngüsü") { Player.shared.loopTap() }
                    .keyboardShortcut("l", modifiers: [])
                Button("Döngüyü Kapat") { Player.shared.clearLoop() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let u = urls.first else { return }
        MainActor.assumeIsolated { Player.shared.open(u) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
func showAbout() {
    let text = "Yavaşlatılabilen, sade ses oynatıcı.\n\nPowered by Nüve Dijital"
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let credits = NSMutableAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.secondaryLabelColor,
        .paragraphStyle: style,
    ])
    let r = (text as NSString).range(of: "Nüve Dijital")
    credits.addAttribute(.link, value: URL(string: "https://nuvedigital.com")!, range: r)
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate()
}
