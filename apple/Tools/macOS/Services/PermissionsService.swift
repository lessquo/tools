import AppKit
@preconcurrency import ApplicationServices
import AVFAudio

@Observable
@MainActor
final class PermissionsService {

    // MARK: - Stateless API
    //
    // For one-off checks and actions from non-view services.
    // Views should prefer the instance properties below so they update reactively.

    static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }
    static var isMicrophoneGranted: Bool { AVAudioApplication.shared.recordPermission == .granted }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        openSettings("Privacy_Accessibility")
    }

    @discardableResult
    static func requestMicrophone() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        case .denied:
            openMicrophoneSettings()
            return false
        case .granted:
            return true
        @unknown default:
            return false
        }
    }

    static func openMicrophoneSettings() {
        openSettings("Privacy_Microphone")
    }

    private static func openSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Observable cache

    private(set) var isAccessibilityGranted: Bool
    private(set) var isMicrophoneGranted: Bool

    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    init() {
        self.isAccessibilityGranted = Self.isAccessibilityGranted
        self.isMicrophoneGranted = Self.isMicrophoneGranted
    }

    deinit {
        pollingTask?.cancel()
    }

    func startPolling(interval: Duration = .seconds(2)) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() {
        let accessibility = Self.isAccessibilityGranted
        if accessibility != isAccessibilityGranted {
            isAccessibilityGranted = accessibility
        }
        let microphone = Self.isMicrophoneGranted
        if microphone != isMicrophoneGranted {
            isMicrophoneGranted = microphone
        }
    }

    // Convenience wrappers that sync cached state after the call.

    func requestAccessibility() {
        Self.requestAccessibility()
    }

    func openAccessibilitySettings() {
        Self.openAccessibilitySettings()
    }

    @discardableResult
    func requestMicrophone() async -> Bool {
        let granted = await Self.requestMicrophone()
        if granted != isMicrophoneGranted {
            isMicrophoneGranted = granted
        }
        return granted
    }

    func openMicrophoneSettings() {
        Self.openMicrophoneSettings()
    }
}
