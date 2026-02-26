//
//  WelcomeWindow.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeWindow: Scene {
    static let windowId = "w_id.welcome"
    
    private var versionInfo: String {
        let version = Bundle.versionString ?? "N/A"
        return "Version \(version)"
    }
    
    var body: some Scene {
        Window("Welcome to GitY", id: Self.windowId) {
            WelcomeWindowView(
                title: Bundle.appName ?? "N/A",
                subtitle1: "A powerful Git client for macOS",
                subtitle2: versionInfo
            )
            .ignoresSafeArea()
            .frame(width: 740, height: 460)
            .task {
                if let window = NSApp.findWindow(Self.windowId) {
                    window.styleMask.insert(.fullSizeContentView)
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    window.isMovableByWindowBackground = true
                    window.titlebarAppearsTransparent = true
                }
            }
            
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
