//
//  ContentView.swift
//  GitY
//
//  Main content view - equivalent to PBGitWindowController
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    
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

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var currentRepository: GitRepository?
    @Published var recentRepositories: [URL] = []
    
    private init() {
        loadRecentRepositories()
    }
    
    func loadRecentRepositories() {
        if let data = UserDefaults.standard.data(forKey: "recentRepositories"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            recentRepositories = urls
        }
    }
    
    func addRecentRepository(_ url: URL) {
        recentRepositories.removeAll { $0 == url }
        recentRepositories.insert(url, at: 0)
        if recentRepositories.count > 10 {
            recentRepositories = Array(recentRepositories.prefix(10))
        }
        if let data = try? JSONEncoder().encode(recentRepositories) {
            UserDefaults.standard.set(data, forKey: "recentRepositories")
        }
    }
}
