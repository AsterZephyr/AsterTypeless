import AppKit
import Carbon
import Foundation

@MainActor
final class FallbackShortcutBridge {
    private static let signature: OSType = 0x41535452
    private static var action: (() -> Void)?
    private static let handler: EventHandlerUPP = { _, eventRef, _ in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == signature else {
            return OSStatus(eventNotHandledErr)
        }

        action?()
        return noErr
    }

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    func register(shortcut: String, handler: @escaping () -> Void) -> Bool {
        unregister()

        guard let descriptor = ShortcutDescriptor(shortcut) else {
            return false
        }

        installHandlerIfNeeded()
        Self.action = handler

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(1))
        let status = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
            Self.action = nil
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        Self.action = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}

private struct ShortcutDescriptor {
    var keyCode: UInt32
    var modifiers: UInt32

    init?(_ value: String) {
        let tokens = value
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return nil
        }

        var parsedModifiers: UInt32 = 0
        var parsedKeyCode: UInt32?

        for token in tokens {
            switch token {
            case "control", "ctrl":
                parsedModifiers |= UInt32(controlKey)
            case "option", "alt":
                parsedModifiers |= UInt32(optionKey)
            case "command", "cmd":
                parsedModifiers |= UInt32(cmdKey)
            case "shift":
                parsedModifiers |= UInt32(shiftKey)
            default:
                parsedKeyCode = Self.keyCodeMap[token]
            }
        }

        guard let parsedKeyCode else {
            return nil
        }

        keyCode = parsedKeyCode
        modifiers = parsedModifiers
    }

    private static let keyCodeMap: [String: UInt32] = [
        "space": UInt32(kVK_Space),
        "return": UInt32(kVK_Return),
        "enter": UInt32(kVK_Return),
        ";": UInt32(kVK_ANSI_Semicolon),
        "semicolon": UInt32(kVK_ANSI_Semicolon),
        "a": UInt32(kVK_ANSI_A),
        "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E),
        "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G),
        "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M),
        "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q),
        "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S),
        "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W),
        "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y),
        "z": UInt32(kVK_ANSI_Z),
    ]
}
