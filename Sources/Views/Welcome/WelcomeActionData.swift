//
//  WelcomeActionData.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeActionData {
    let title: String
    let image: ImageSource
    let shortcut: KeyboardShortcut?
    let action: () -> Void
}
