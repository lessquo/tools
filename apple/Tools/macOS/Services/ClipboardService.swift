import AppKit
import Carbon.HIToolbox

@MainActor
final class ClipboardService {

    func save() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func restore(_ content: String?) {
        NSPasteboard.general.clearContents()
        if let content {
            NSPasteboard.general.setString(content, forType: .string)
        }
    }

    func write(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func simulateCopy() async throws {
        try simulateKeyPress(keyCode: UInt16(kVK_ANSI_C), flags: .maskCommand)
        try await Task.sleep(for: .milliseconds(150))
    }

    func simulatePaste() async throws {
        try simulateKeyPress(keyCode: UInt16(kVK_ANSI_V), flags: .maskCommand)
    }

    // MARK: - Private

    private func simulateKeyPress(keyCode: UInt16, flags: CGEventFlags) throws {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw ClipboardError.eventCreationFailed
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

enum ClipboardError: LocalizedError {
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            return "Failed to create keyboard event"
        }
    }
}
