//
//  WelcomeWindow.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeWindow: Scene {
    static let windowId = "w_id.welcome"
    
    var body: some Scene {
        Window("Welcome to GitY", id: Self.windowId) {
            WelcomeWindowView(title: "GitY", subtitle: "Version 1.0")
                .ignoresSafeArea()
                .frame(width: 740, height: 460)
                .task {
                    if let window = NSApp.findWindow(Self.windowId) {
                        window.styleMask.insert(.fullSizeContentView)
                        window.standardWindowButton(.closeButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.isMovableByWindowBackground = true
                        
                        // Ensure the title bar is physically hidden/transparent
                        window.titlebarAppearsTransparent = true
                    }
                }

        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}


extension NSApplication {
    func findWindow(_ id: String) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id }
    }
}
