//
//  WelcomeActionButton.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeActionButton: View {
    let data: WelcomeActionData
    
    init(_ data: WelcomeActionData) {
        self.data = data
    }
    
    var body: some View {
        Button(action: data.action) {
            HStack(spacing: 12) {
                Image(data.image)
                Text(data.title)
                Spacer()
                if let shortcut = data.shortcut {
                    KeyboardShortcutView(shortcut: shortcut)
                }
            }
            .frame(height: 25)
        }
        .cornerRadius(25)
        .buttonStyle(.bordered)
        .pointingHandCursor()
    }
}


#Preview {
    let actions = [
        WelcomeActionData(
            title: "Open repository...",
            image: .system("folder"),
            shortcut: KeyboardShortcut("O", modifiers: .command),
            action: {
                // no op
            }
        ),
        
        WelcomeActionData(
            title: "Clone repository...",
            image: .system("square.and.arrow.down.on.square"),
            shortcut: KeyboardShortcut("C", modifiers: .command),
            action: {
                // no op
            }
        )
        
    ]
    VStack(spacing: 10) {
        ForEach(actions.indices, id: \.self) {
            WelcomeActionButton(actions[$0])
        }
    }
    .padding(50)
}
