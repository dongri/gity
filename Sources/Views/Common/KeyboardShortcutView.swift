//
//  KeyboardShortcutView.swift
//  GitY
//
//  Created by Sergey on 23.02.2026.
//

import SwiftUI

struct KeyboardShortcutView: View {
    let shortcut: KeyboardShortcut
    
    var body: some View {
        HStack {
            modifiers
            key
        }
    }
    
    @ViewBuilder
    private var key: some View {
        switch shortcut.key {
        case .upArrow:
            Image(.system("arrowshape.up"))
        case .downArrow:
            Image(.system("arrowshape.down"))
        case .leftArrow:
            Image(.system("arrowshape.left"))
        case .rightArrow:
            Image(.system("arrowshape.right"))
        case .space:
            Image(.system("space"))
        case .return:
            Image(.system("return"))
        case .tab:
            Text("Tab")
        case .escape:
            Text("Esc")
        case .pageUp:
            Text("PgUp")
        case .pageDown:
            Text("PgDn")
        case .home:
            Text("Home")
        case .end:
            Text("End")
        default:
            Text(String(shortcut.key.character))
        }
    }
    
    var modifiers: some View {
        Group {
            if shortcut.modifiers.contains(.control) {
                Image(.system("control"))
            }
            if shortcut.modifiers.contains(.option) {
                Image(.system("option"))
            }
            if shortcut.modifiers.contains(.command) {
                Image(.system("command"))
            }
            if shortcut.modifiers.contains(.shift) {
                Image(.system("shift"))
            }
            if shortcut.modifiers.contains(.capsLock) {
                Text("Caps")
            }
            if shortcut.modifiers.contains(.numericPad) {
                Text("Num")
            }
        }
    }
}

#Preview {
    let shortcuts: [KeyboardShortcut] = [
        KeyboardShortcut(.upArrow, modifiers: [.capsLock, .numericPad]),
        KeyboardShortcut(.downArrow, modifiers: [.option, .command]),
        KeyboardShortcut(.leftArrow, modifiers: [.control]),
        KeyboardShortcut(.rightArrow, modifiers: [.shift]),
        KeyboardShortcut(.escape, modifiers: [.option]),
        KeyboardShortcut("1" , modifiers: [.command]),
    ]
    VStack(spacing: 5) {
        ForEach(shortcuts, id: \.self) {
            KeyboardShortcutView(
                shortcut: $0
            )
        }
    }
    .padding(.horizontal, 150)
    .padding(.vertical, 10)
}
