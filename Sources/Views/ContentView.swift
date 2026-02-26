//
//  ContentView.swift
//  GitY
//
//  Main content view - equivalent to PBGitWindowController
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if let repository = appState.currentRepository {
                MainRepositoryView(repository: repository)
            } else {
                WelcomeView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRepository)) { _ in
            openRepository()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRepositoryURL)) { notification in
            if let url = notification.object as? URL {
                openRepository(at: url)
            }
        }
    }
    
    private func openRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Git repository"
        
        if panel.runModal() == .OK, let url = panel.url {
            openRepository(at: url)
        }
    }
    
    private func openRepository(at url: URL) {
        do {
            let repository = try GitRepository(url: url)
            appState.currentRepository = repository
            Task {
                await repository.loadCommits()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to open repository"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}
