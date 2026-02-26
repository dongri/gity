//
//  NSApp+Utils.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import AppKit
import Foundation

extension NSApplication {
    func findWindow(_ id: String) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id }
    }
}
