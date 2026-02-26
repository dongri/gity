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
        
    func addRecentRepository(_ url: URL) {
        recentRepositories.removeAll { $0 == url }
        recentRepositories.insert(url, at: 0)
        if recentRepositories.count > 10 {
            recentRepositories = Array(recentRepositories.prefix(10))
        }
        saveRecentRepositoriesList()
    }
    
    func clearRecentRepositories() {
        recentRepositories.removeAll()
        saveRecentRepositoriesList()
    }
    
    // MARK: utils for load/store data
    private func loadRecentRepositories() {
        if let data = UserDefaults.standard.data(forKey: "recentRepositories"),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            recentRepositories = urls
        }
    }

    private func saveRecentRepositoriesList() {
        if let data = try? JSONEncoder().encode(recentRepositories) {
            UserDefaults.standard.set(data, forKey: "recentRepositories")
        }
    }
}
