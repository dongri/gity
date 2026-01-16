//
//  GitRef.swift
//  GitY
//
//  Git reference model - branches, tags, remotes
//

import Foundation

enum GitRefType {
    case branch
    case remoteBranch
    case tag
    case stash
    case head
    case other
}

struct GitRef: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: GitRefType
    var sha: String?
    
    var displayName: String {
        switch type {
        case .remoteBranch:
            // Remove remote prefix for display
            let parts = name.components(separatedBy: "/")
            if parts.count > 1 {
                return parts.dropFirst().joined(separator: "/")
            }
            return name
        default:
            return name
        }
    }
    
    var remoteName: String? {
        guard type == .remoteBranch else { return nil }
        let parts = name.components(separatedBy: "/")
        return parts.first
    }
    
    var icon: String {
        switch type {
        case .branch:
            return "arrow.triangle.branch"
        case .remoteBranch:
            return "cloud"
        case .tag:
            return "tag"
        case .stash:
            return "archivebox"
        case .head:
            return "circle.fill"
        case .other:
            return "doc"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
    }
    
    static func == (lhs: GitRef, rhs: GitRef) -> Bool {
        return lhs.name == rhs.name && lhs.type == rhs.type
    }
}
