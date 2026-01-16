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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.hasDirectoryPath {
                NotificationCenter.default.post(name: .openRepositoryURL, object: url)
            }
        }
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
