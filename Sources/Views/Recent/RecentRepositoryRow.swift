//
//  RecentRepositoryRow.swift
//  GitY
//
//  Created by Sergey on 23.02.2026.
//

import SwiftUI

struct RecentRepositoryRow: View {
    let data: RecentRepositoryData
    
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .openRepositoryURL, object: url)
        } label: {
            HStack {
                Image(systemName: "folder.fill")
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
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .ifLet(option: data.shortcut) { view, shortcut in
            view
                .keyboardShortcut(shortcut)
        }
    }
    
    private var url: URL {
        data.url
    }
}
