//
//  RecentView.swift
//  GitY
//
//  Created by Sergey on 23.02.2026.
//

import SwiftUI

struct RecentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        if recent.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(recent, id: \.self) { data in
                    RecentRepositoryRow(data: data) {
                        NotificationCenter.default.post(name: .openRepositoryURL, object: data.url)
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        appState.clearRecentRepositories()
                    } label: {
                        Text("Clear recents")
                    }
                }
            }
        }
    }
    
    private var recent: [RecentRepositoryData] {
        let count = min(Self.maxItems, appState.recentRepositories.count)
        return (0..<count)
            .map {
                let url = appState.recentRepositories[$0]
                let shortcut = Self.shortcuts.count > $0 ? Self.shortcuts[$0] : nil
                return RecentRepositoryData(url: url, shortcut: shortcut)
            }
    }
    
    private static let maxItems = 8
    
    private static let shortcuts: [KeyboardShortcut] = {
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            KeyboardShortcut($0, modifiers: .command)
        }
    }()
}

struct RecentRepositoryData: Hashable {
    let url: URL
    let shortcut: KeyboardShortcut?
}

#Preview {
    let state = AppState()
    RecentView()
        .environmentObject(state)
}
