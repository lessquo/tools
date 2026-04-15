import Foundation
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class ShortcutMonitor {

    var onActivate: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?

    func start() {
        guard eventTap == nil else { return }
        guard ClipboardService.checkAccessibilityPermission() else {
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
    }

    deinit {
        pollingTimer?.invalidate()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    // MARK: - Private

    private func setupEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: shortcutCallback,
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
                if ClipboardService.checkAccessibilityPermission() {
                    self.pollingTimer?.invalidate()
                    self.pollingTimer = nil
                    self.setupEventTap()
                }
            }
        }
    }
}

private func shortcutCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // ⌘; (Command + Semicolon)
    if keyCode == kVK_ANSI_Semicolon,
       flags.contains(.maskCommand),
       !flags.contains(.maskShift),
       !flags.contains(.maskAlternate),
       !flags.contains(.maskControl) {
        let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        DispatchQueue.main.async {
            monitor.onActivate?()
        }
        return nil // swallow the event
    }

    return Unmanaged.passUnretained(event)
}
