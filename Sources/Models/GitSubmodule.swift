//
//  GitSubmodule.swift
//  GitY
//
//  Git submodule model
//

import Foundation

struct GitSubmodule: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let sha: String
    
    var name: String {
        return (path as NSString).lastPathComponent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: GitSubmodule, rhs: GitSubmodule) -> Bool {
        return lhs.path == rhs.path
    }
}
