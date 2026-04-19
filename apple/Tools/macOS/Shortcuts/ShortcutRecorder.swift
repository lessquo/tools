import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutSettingRow: View {
    @Binding var shortcut: Shortcut
    var lockedMode: Shortcut.Mode? = nil
    var defaultShortcut: Shortcut

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)
                .font(.footnote)
            Text("Shortcut")
                .font(.callout)
            Spacer(minLength: 8)
            ShortcutRecorder(
                shortcut: $shortcut,
                lockedMode: lockedMode,
                defaultShortcut: defaultShortcut
            )
        }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    var lockedMode: Shortcut.Mode? = nil
    var defaultShortcut: Shortcut

    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            RecorderField(
                shortcut: $shortcut,
                isRecording: $isRecording,
                lockedMode: lockedMode
            )
            if lockedMode == nil {
                Picker("", selection: Binding(
                    get: { shortcut.mode },
                    set: { shortcut.mode = $0 }
                )) {
                    Text("Tap").tag(Shortcut.Mode.tap)
                    Text("Hold").tag(Shortcut.Mode.hold)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                .controlSize(.small)
            }
            Button("Reset") { shortcut = defaultShortcut }
                .controlSize(.small)
        }
    }
}

private struct RecorderField: View {
    @Binding var shortcut: Shortcut
    @Binding var isRecording: Bool
    let lockedMode: Shortcut.Mode?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isRecording ? Color.accentColor.opacity(0.15) : Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.accentColor : Color(nsColor: .separatorColor))
                )
            Text(isRecording ? "Press shortcut…" : shortcut.display)
                .font(.callout)
                .monospaced()
                .foregroundStyle(isRecording ? .secondary : .primary)
                .padding(.horizontal, 8)
        }
        .frame(minWidth: 110, minHeight: 22)
        .fixedSize(horizontal: true, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture { isRecording.toggle() }
        .background(
            ShortcutCaptureRep(
                isRecording: $isRecording,
                onCapture: { captured in
                    var next = captured
                    if let lockedMode { next.mode = lockedMode }
                    shortcut = next
                }
            )
        )
    }
}

private struct ShortcutCaptureRep: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (Shortcut) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isRecording = isRecording
        context.coordinator.onCapture = { captured in
            onCapture(captured)
            isRecording = false
        }
        context.coordinator.onCancel = { isRecording = false }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var isRecording = false
        var onCapture: ((Shortcut) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?
        private var pendingModifiers: UInt64 = 0

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self, self.isRecording else { return event }
                return self.handle(event)
            }
        }

        func uninstall() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { uninstall() }

        private func handle(_ event: NSEvent) -> NSEvent? {
            let flags = event.cgEvent?.flags.rawValue ?? 0
            let mods = flags & Shortcut.trackedModifierMask

            switch event.type {
            case .keyDown:
                if Int(event.keyCode) == kVK_Escape {
                    onCancel?()
                    return nil
                }
                let captured = Shortcut(
                    keyCode: Int(event.keyCode),
                    modifiers: mods,
                    mode: .tap
                )
                onCapture?(captured)
                return nil

            case .flagsChanged:
                if mods != 0 {
                    pendingModifiers = mods
                } else if pendingModifiers != 0 {
                    // All modifiers released without a keyDown → commit as modifier-only hold.
                    let captured = Shortcut(
                        keyCode: nil,
                        modifiers: pendingModifiers,
                        mode: .hold
                    )
                    pendingModifiers = 0
                    onCapture?(captured)
                    return nil
                }
                return event

            default:
                return event
            }
        }
    }
}
