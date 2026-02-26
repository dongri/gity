//
//  AppState.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var currentRepository: GitRepository? {
        didSet {
            if let currentRepository {
                addRecentRepository(currentRepository.url)
            }
        }
    }
    @Published var recentRepositories: [URL] = []
        
    func setup() {
        loadRecentRepositories()
    }
    
    private func loadRecentRepositories() {
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
    
    func clearRecentRepositories() {
        recentRepositories.removeAll()
    }
}
