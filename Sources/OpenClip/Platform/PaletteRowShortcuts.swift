// PaletteRowShortcuts.swift
// OpenClip
//
// ⌘1…⌘9 for the search palette's first nine rows, registered as *global* hot keys for exactly as
// long as the palette is on screen.
//
// They have to be global. macOS routes a command-modified key to the **active application**, and
// the popup is a non-activating panel of an app that is deliberately never active: plain keys
// reach the key panel (typing in the palette works), but a ⌘-digit is delivered to whatever app
// the user is working in — it never enters OpenClip's event stream at all, so neither an event
// monitor nor `performKeyEquivalent` on the panel can see it, and the source app rings the bell
// for a shortcut it does not recognize. Raycast and Chrome get these keys because they *are* the
// active app; OpenClip's whole point is not to steal that.
//
// So the same Carbon hot-key mechanism the ⌥⌘C trigger already uses (via KeyboardShortcuts) takes
// ⌘1…⌘9 system-wide while the palette is open, and hands them back the moment it closes. That
// also consumes them, so the source app never sees the keystroke.
import AppKit
import Core
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let paletteRow1 = Self("paletteRow1", initial: .init(.one, modifiers: [.command]))
    static let paletteRow2 = Self("paletteRow2", initial: .init(.two, modifiers: [.command]))
    static let paletteRow3 = Self("paletteRow3", initial: .init(.three, modifiers: [.command]))
    static let paletteRow4 = Self("paletteRow4", initial: .init(.four, modifiers: [.command]))
    static let paletteRow5 = Self("paletteRow5", initial: .init(.five, modifiers: [.command]))
    static let paletteRow6 = Self("paletteRow6", initial: .init(.six, modifiers: [.command]))
    static let paletteRow7 = Self("paletteRow7", initial: .init(.seven, modifiers: [.command]))
    static let paletteRow8 = Self("paletteRow8", initial: .init(.eight, modifiers: [.command]))
    static let paletteRow9 = Self("paletteRow9", initial: .init(.nine, modifiers: [.command]))
}

@MainActor
enum PaletteRowShortcuts {
    /// Row number (1-based) → its shortcut name, in row order.
    static let names: [KeyboardShortcuts.Name] = [
        .paletteRow1, .paletteRow2, .paletteRow3, .paletteRow4, .paletteRow5,
        .paletteRow6, .paletteRow7, .paletteRow8, .paletteRow9
    ]

    /// Runs the 1-based row, returning false when there is no such row. Set by the composition
    /// root; nil until then.
    private static var runRow: ((Int) -> Bool)?
    private static var isInstalled = false
    private(set) static var isActive = false

    /// Registers the handlers once and immediately parks the keys: ⌘1…⌘9 belong to the rest of
    /// the system until a palette actually opens.
    static func install(runRow: @escaping (Int) -> Bool) {
        self.runRow = runRow
        guard !isInstalled else { return }
        isInstalled = true
        for (index, name) in names.enumerated() {
            let row = index + 1
            KeyboardShortcuts.onKeyDown(for: name) {
                MainActor.assumeIsolated {
                    let handled = Self.runRow?(row) ?? false
                    Log.presentation.debug("palette shortcut ⌘\(row, privacy: .public) handled=\(handled, privacy: .public)")
                }
            }
        }
        setActive(false)
    }

    /// Takes the keys while the palette is up, hands them back when it goes away. Idempotent, so
    /// every popup transition can simply state what it wants.
    static func setActive(_ active: Bool) {
        guard active != isActive || !active else { return }
        isActive = active
        if active {
            KeyboardShortcuts.enable(names)
        } else {
            KeyboardShortcuts.disable(names)
        }
    }
}
