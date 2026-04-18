import AppKit
import Carbon.HIToolbox
import SwiftUI

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class QuickActions {

    private var panel: NSPanel?
    private var service: ActionService?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private let llmService: LLMService
    private let modelStore: ModelStore
    private let actionStore: ActionStore
    private let menuHandler = ActionMenuHandler()
    private var panelOrigin: CGPoint = .zero

    init(llmService: LLMService, modelStore: ModelStore, actionStore: ActionStore) {
        self.llmService = llmService
        self.modelStore = modelStore
        self.actionStore = actionStore
        menuHandler.onPick = { [weak self] action in
            self?.handleMenuPick(action)
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { dismiss() } else { showMenu() }
    }

    private func showMenu() {
        panelOrigin = NSEvent.mouseLocation
        let actions = actionStore.actions
        let menu = NSMenu()
        menu.autoenablesItems = false

        if actions.isEmpty {
            let item = NSMenuItem(title: "No actions configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for (index, action) in actions.enumerated() {
                let keyEquivalent = index < 9 ? "\(index + 1)" : ""
                let item = NSMenuItem(
                    title: action.name,
                    action: #selector(ActionMenuHandler.pick(_:)),
                    keyEquivalent: keyEquivalent
                )
                item.keyEquivalentModifierMask = []
                item.target = menuHandler
                item.representedObject = action
                menu.addItem(item)
            }
        }

        menu.popUp(positioning: nil, at: panelOrigin, in: nil)
    }

    private func handleMenuPick(_ action: Action) {
        presentPanel()
        triggerAction(action)
    }

    private func presentPanel() {
        let service = ActionService(llm: llmService, modelStore: modelStore)
        self.service = service

        let view = QuickActionsView(
            service: service,
            onClose: { [weak self] in self?.close() },
            onDismiss: { [weak self] in self?.dismiss() },
            onMakeKey: { [weak self] in self?.panel?.makeKey() }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = .intrinsicContentSize
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true

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
        hostingView.layoutSubtreeIfNeeded()

        // Position near where the menu was invoked
        let panelSize = hostingView.fittingSize
        var origin = CGPoint(
            x: panelOrigin.x,
            y: panelOrigin.y - panelSize.height
        )

        // Clamp to screen bounds
        if let screen = NSScreen.main?.visibleFrame {
            origin.x = min(origin.x, screen.maxX - panelSize.width)
            origin.x = max(origin.x, screen.minX)
            origin.y = max(origin.y, screen.minY)
            origin.y = min(origin.y, screen.maxY - panelSize.height)
        }

        panel?.setFrame(NSRect(origin: origin, size: panelSize), display: false)
        panel?.orderFrontRegardless()
        panel?.makeKey()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Int(event.keyCode) == kVK_Escape { self?.dismiss() }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            if keyCode == kVK_Escape { self.dismiss(); return nil }

            guard let service = self.service else { return event }

            // ⌘↩ to apply result (keyboardShortcut doesn't work on nonactivatingPanel)
            if case .ready = service.status,
               keyCode == kVK_Return,
               event.modifierFlags.contains(.command) {
                self.close()
                Task { await service.applyResult() }
                return nil
            }

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

    private func triggerAction(_ action: Action) {
        guard let service else { return }
        panel?.resignKey()
        Task {
            guard let text = await service.copySelectedText() else { return }
            await service.processAction(action, text: text)
        }
    }
}

private final class ActionMenuHandler: NSObject {
    var onPick: ((Action) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? Action else { return }
        onPick?(action)
    }
}
