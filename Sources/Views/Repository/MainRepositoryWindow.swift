//
//  MainRepositoryWindow.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct MainRepositoryWindow: Scene {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    private let windowId: String
        
    init(id: String) {
        self.windowId = id
    }
    
    var body: some Scene {
        Window("Gity", id: windowId) {
            Group {
                if let repository = appState.currentRepository {
                    MainRepositoryView(repository: repository)
                        .onDisappear {
                            appState.currentRepository = nil
                        }
                } else {
                    EmptyView()
                        .task {
                            dismiss()
                        }
                }
                
            }
        }
    }
}
