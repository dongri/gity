//
//  WelcomeView.swift
//  GitY
//
//  Welcome view when no repository is open
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("GitY")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            
            Text("A powerful Git client for macOS")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Actions
            HStack(spacing: 20) {
                ActionButton(title: "Open Repository", icon: "folder", action: openRepository)

            }
            
            Spacer()
            
            // Recent Repositories
            if !appState.recentRepositories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Repositories")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(appState.recentRepositories.prefix(5), id: \.self) { url in
                        RecentRepositoryRow(url: url)
                    }
                }
                .frame(maxWidth: 400)
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func openRepository() {
        NotificationCenter.default.post(name: .openRepository, object: nil)
    }
    

}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                Text(title)
                    .font(.headline)
            }
            .frame(width: 160, height: 100)
        }
        .buttonStyle(.bordered)
        .pointingHandCursor()
    }
}

struct RecentRepositoryRow: View {
    let url: URL
    
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
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}
