//
//  GitYApp.swift
//  GitY
//
//  A Swift rewrite of GitX - A macOS Git client
//

import SwiftUI
import Cocoa

@main
struct GitYApp: App {
    enum Window: String {
        case welcome = "w_id.welcome"
        case repository = "w_id.repository"
    }
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState: AppState
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    init() {
        let appState = AppState()
        self._appState = StateObject(wrappedValue: appState)
        appState.setup()
    }
    
    var body: some Scene {
        Group {
            Group {
                WelcomeWindow(
                    id: Window.welcome.rawValue
                )
                
                MainRepositoryWindow(
                    id: Window.repository.rawValue
                )
            }
            .environmentObject(appState)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Open Repository...", action: selectRepository)
                        .keyboardShortcut("O", modifiers: .command)
                }
                CommandGroup(after: .newItem) {
                    Button("Clone Repository...", action: cloneRepository)
                        .keyboardShortcut("C", modifiers: [.command, .shift])
                }
            }
            
            Settings {
                PreferencesView()
            }
        }
    }
    
    private func selectRepository() {
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
            openWindow(id: Window.repository.rawValue)
            dismissWindow(id: Window.welcome.rawValue)
            
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
    
    private func cloneRepository() {
        let alert = NSAlert()
        alert.messageText = "Sorry, clone repository isn't implemented yet"
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func closeRepository(_ url: URL) {
        appState.currentRepository = nil
        dismissWindow(id: Window.repository.rawValue)
        openWindow(id: Window.welcome.rawValue)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears in the Dock and has a menu bar
        // This is necessary when running via `swift run` or as a CLI binary
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.hasDirectoryPath {
                // Traverse up to find the nearest .git directory
                let repoURL = findGitRoot(from: url) ?? url
                NotificationCenter.default.post(name: .openRepositoryURL, object: repoURL)
            }
        }
    }
    
    /// Walk up from the given directory to find the nearest parent containing `.git`
    private func findGitRoot(from url: URL) -> URL? {
        var current = url.standardizedFileURL
        let fileManager = FileManager.default
        while current.path != "/" {
            let gitDir = current.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openRepository = Notification.Name("openRepository")
    static let cloneRepository = Notification.Name("cloneRepository")
    static let openRepositoryURL = Notification.Name("openRepositoryURL")
    static let repositoryChanged = Notification.Name("repositoryChanged")
    static let branchChanged = Notification.Name("branchChanged")
    static let indexChanged = Notification.Name("indexChanged")
}
