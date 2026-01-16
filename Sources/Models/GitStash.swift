//
//  GitStash.swift
//  GitY
//
//  Git stash model
//

import Foundation

struct GitStash: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let sha: String
    let message: String
    
    var displayName: String {
        return "stash@{\(index)}: \(message)"
    }
    
    var shortName: String {
        return "stash@{\(index)}"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(index)
        hasher.combine(sha)
    }
    
    static func == (lhs: GitStash, rhs: GitStash) -> Bool {
        return lhs.index == rhs.index && lhs.sha == rhs.sha
    }
}
