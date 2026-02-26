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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState: AppState
    
    init() {
        let appState = AppState()
        self._appState = StateObject(wrappedValue: appState)
        appState.setup()
    }
    
    var body: some Scene {
        Group {
            WelcomeWindow()
            
            WindowGroup {
                ContentView()
                    .frame(minWidth: 900, minHeight: 600)
                    .environmentObject(appState)
//                    .task {
//                        appState.setup()
//                    }
            }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Open Repository...") {
                        NotificationCenter.default.post(name: .openRepository, object: nil)
                    }
                    .keyboardShortcut("O", modifiers: .command)
                }
                
                CommandGroup(after: .newItem) {
                    Button("Clone Repository...") {
                        NotificationCenter.default.post(name: .cloneRepository, object: nil)
                    }
                    .keyboardShortcut("C", modifiers: [.command, .shift])
                }
            }
            
            Settings {
                PreferencesView()
            }
        }.environmentObject(appState)
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
