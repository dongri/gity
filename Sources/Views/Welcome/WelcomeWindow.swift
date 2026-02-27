//
//  WelcomeWindow.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeWindow: Scene {
    private let windowId: String
    private let actionCommands: [ActionHolder]
    
    private var versionInfo: String {
        let version = Bundle.versionString ?? "N/A"
        return "Version \(version)"
    }
    
    init(
        id: String,
        actionCommands: [ActionHolder]
    ) {
        self.windowId = id
        self.actionCommands = actionCommands
    }
    
    var body: some Scene {
        Window("Welcome to GitY", id: windowId) {
            WelcomeWindowView(
                title: Bundle.appName ?? "N/A",
                subtitle1: "A powerful Git client for macOS",
                subtitle2: versionInfo,
                actionCommands: actionCommands
            )
            .ignoresSafeArea()
            .frame(width: 740, height: 460)
            .task {
                if let window = NSApp.findWindow(windowId) {
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
