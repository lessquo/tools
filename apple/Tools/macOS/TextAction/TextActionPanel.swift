import AppKit
import SwiftUI

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class TextActionPanel {

    private var panel: NSPanel?
    private var service: TextActionService?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private let aiService: AIService
    private let modelStore: ModelStore

    init(aiService: AIService, modelStore: ModelStore) {
        self.aiService = aiService
        self.modelStore = modelStore
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { dismiss() } else { show() }
    }

    func show() {
        let service = TextActionService(ai: aiService, modelStore: modelStore)
        self.service = service

        let view = TextActionPanelView(
            service: service,
            onClose: { [weak self] in self?.close() },
            onDismiss: { [weak self] in self?.dismiss() },
            onMakeKey: { [weak self] in self?.panel?.makeKey() }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = .intrinsicContentSize

        if panel == nil {
            let p = KeyablePanel(
                contentRect: .zero,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: true
            )
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.becomesKeyOnlyIfNeeded = true
            panel = p
        }

        panel?.contentView = hostingView

        // Position near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let panelSize = hostingView.fittingSize
        var origin = CGPoint(
            x: mouseLocation.x,
            y: mouseLocation.y - panelSize.height
        )

        // Clamp to screen bounds
        if let screen = NSScreen.main?.visibleFrame {
            origin.x = min(origin.x, screen.maxX - panelSize.width)
            origin.x = max(origin.x, screen.minX)
            origin.y = max(origin.y, screen.minY)
            origin.y = min(origin.y, screen.maxY - panelSize.height)
        }

        panel?.setFrameOrigin(origin)
        panel?.orderFrontRegardless()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss() }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss(); return nil }
            return event
        }
    }

    func close() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        panel?.orderOut(nil)
        service = nil
    }

    func dismiss() {
        service?.dismiss()
        close()
    }
}
