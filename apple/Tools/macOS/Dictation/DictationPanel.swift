import AppKit
import SwiftUI

/// Floating, non-activating HUD panel for push-to-talk dictation.
/// Does NOT steal focus: the target text field stays first responder
/// so the synthesized ⌘V lands in the right place.
@MainActor
final class DictationPanel {

    private let panel: NSPanel
    private let hostingView: NSHostingView<DictationPanelView>

    init(audio: AudioCaptureService, stt: STTService) {
        let view = DictationPanelView(audio: audio, stt: stt)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        self.hostingView = hosting

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        self.panel = panel
    }

    func show() {
        positionAtTop()
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    // MARK: - Private

    private func positionAtTop() {
        let screen = targetScreen()
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 40  // 40pt below menu bar
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
