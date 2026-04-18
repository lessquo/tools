import Foundation
@preconcurrency import ApplicationServices

/// Watches the `fn` (globe) key globally and fires press/release callbacks.
/// Requires the Accessibility permission (same as `ShortcutMonitor`).
@MainActor
final class HoldShortcutMonitor {

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollingTimer: Timer?
    private var isFnHeld = false

    func start() {
        guard eventTap == nil else { return }
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
        isFnHeld = false
    }

    deinit {
        pollingTimer?.invalidate()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    // MARK: - Called from the CGEventTap callback

    fileprivate func handleFlagsChanged(_ flags: CGEventFlags) {
        let fnDown = flags.contains(.maskSecondaryFn)
        if fnDown, !isFnHeld {
            isFnHeld = true
            onPress?()
        } else if !fnDown, isFnHeld {
            isFnHeld = false
            onRelease?()
        }
    }

    // MARK: - Private

    private func setupEventTap() {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: holdShortcutCallback,
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

private func holdShortcutCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .flagsChanged, let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let flags = event.flags
    let monitor = Unmanaged<HoldShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.handleFlagsChanged(flags)
    }
    return Unmanaged.passUnretained(event)
}
