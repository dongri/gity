//
//  RecentRepositoryRow.swift
//  GitY
//
//  Created by Sergey on 23.02.2026.
//

import SwiftUI

struct RecentRepositoryRow: View {
    let data: RecentRepositoryData
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(.system("folder.fill"))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(.body, design: .monospaced))
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                if let shortcut = data.shortcut {
                    KeyboardShortcutView(shortcut: shortcut)
                        .foregroundColor(.secondary)
                } else {
                    Image(.system("chevron.right"))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .optionalKeyboardShortcut(data.shortcut)
    }
    
    private var url: URL {
        data.url
    }
}
