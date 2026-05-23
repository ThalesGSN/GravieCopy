import Carbon.HIToolbox

// Registers a global system-wide hotkey (Cmd+Shift+V) using Carbon's
// RegisterEventHotKey API — the only way to intercept key events globally
// on macOS without Input Monitoring or Accessibility permissions.
final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()

    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, ptr -> OSStatus in
                guard let ptr else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotkeyManager>.fromOpaque(ptr)
                    .takeUnretainedValue()
                    .onActivate?()
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )

        var hkID = EventHotKeyID(signature: 0x47524356, id: 1) // 'GRCV'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        hotKeyRef.map { UnregisterEventHotKey($0) }
        handlerRef.map { RemoveEventHandler($0) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
