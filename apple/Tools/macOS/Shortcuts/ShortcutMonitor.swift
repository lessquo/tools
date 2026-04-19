import Foundation
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

/// Watches a configurable global shortcut. Supports both tap (fire on key down)
/// and hold (fire press/release) modes, including modifier-only shortcuts like `fn`.
/// Requires the Accessibility permission; falls back to polling until granted.
@MainActor
final class ShortcutMonitor {

    var onActivate: (() -> Void)?  // tap mode
    var onPress: (() -> Void)?     // hold mode
    var onRelease: (() -> Void)?   // hold mode

    private var shortcut: Shortcut?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?
    private var isHeld = false

    func start(_ shortcut: Shortcut) {
        stop()
        guard !shortcut.isEmpty else { return }
        self.shortcut = shortcut
        guard PermissionsService.isAccessibilityGranted else {
            startPolling()
            return
        }
        setupEventTap()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if isHeld {
            isHeld = false
            onRelease?()
        }
        shortcut = nil
    }

    deinit {
        pollingTimer?.invalidate()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    // MARK: - Event handling

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard let shortcut else { return false }
        let flags = event.flags.rawValue & Shortcut.trackedModifierMask
        let required = shortcut.modifiers & Shortcut.trackedModifierMask

        switch (shortcut.mode, shortcut.keyCode) {
        case (.tap, let keyCode?):
            guard type == .keyDown else { return false }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if code == keyCode, flags == required {
                DispatchQueue.main.async { [weak self] in self?.onActivate?() }
                return true
            }
            return false

        case (.tap, nil):
            // Modifier-only tap isn't meaningful — treat as no match.
            return false

        case (.hold, nil):
            guard type == .flagsChanged else { return false }
            let match = required != 0 && (flags == required)
            if match, !isHeld {
                isHeld = true
                DispatchQueue.main.async { [weak self] in self?.onPress?() }
            } else if !match, isHeld {
                isHeld = false
                DispatchQueue.main.async { [weak self] in self?.onRelease?() }
            }
            return false

        case (.hold, let keyCode?):
            switch type {
            case .keyDown:
                let code = event.getIntegerValueField(.keyboardEventKeycode)
                if code == keyCode, flags == required, !isHeld {
                    isHeld = true
                    DispatchQueue.main.async { [weak self] in self?.onPress?() }
                    return true
                }
                return false
            case .keyUp:
                let code = event.getIntegerValueField(.keyboardEventKeycode)
                if code == keyCode, isHeld {
                    isHeld = false
                    DispatchQueue.main.async { [weak self] in self?.onRelease?() }
                    return true
                }
                return false
            case .flagsChanged:
                // Release if user drops a required modifier mid-hold.
                if isHeld, (flags & required) != required {
                    isHeld = false
                    DispatchQueue.main.async { [weak self] in self?.onRelease?() }
                }
                return false
            default:
                return false
            }
        }
    }

    // MARK: - Setup

    private func setupEventTap() {
        guard let shortcut else { return }

        var mask: CGEventMask = 0
        mask |= CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        if shortcut.keyCode != nil || shortcut.mode == .tap {
            mask |= CGEventMask(1 << CGEventType.keyDown.rawValue)
        }
        if shortcut.mode == .hold, shortcut.keyCode != nil {
            mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
        }

        // Modifier-only hold only needs to listen; everything else may swallow.
        let options: CGEventTapOptions = (shortcut.mode == .hold && shortcut.keyCode == nil)
            ? .listenOnly
            : .defaultTap

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: mask,
            callback: shortcutMonitorCallback,
            userInfo: userInfo
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.eventTap == nil else {
                    self?.pollingTimer?.invalidate()
                    self?.pollingTimer = nil
                    return
                }
                if PermissionsService.isAccessibilityGranted {
                    self.pollingTimer?.invalidate()
                    self.pollingTimer = nil
                    self.setupEventTap()
                }
            }
        }
    }
}

private func shortcutMonitorCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    // The callback is invoked on the main thread because the run loop source is on main.
    let swallow = MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
