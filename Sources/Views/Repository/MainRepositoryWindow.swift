//
//  MainRepositoryWindow.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct MainRepositoryWindow: Scene {
    @EnvironmentObject var appState: AppState
    @Environment(\.closeRepository) var closeRepository
    
    private let windowId: String
    
    init(id: String) {
        self.windowId = id
    }
    
    var body: some Scene {
        Window("Gity", id: windowId) {
            if let repository = appState.currentRepository {
                MainRepositoryView(repository: repository)
                    .onDisappear {
                        closeRepository()
                    }
            } else {
                Rectangle()
                    .foregroundStyle(.clear)
                    .background(.clear)
                    .task {
                        try? await Task.sleep(for: .seconds(2.0))
                        if appState.currentRepository == nil {
                            closeRepository()
                        }
                    }
            }
        }
    }
}
