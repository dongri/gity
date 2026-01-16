//
//  ChangedFile.swift
//  GitY
//
//  Changed file model for staging view
//

import Foundation
import AppKit

enum FileStatus: String {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case unmerged = "U"
    case typeChanged = "T"
    
    static func from(gitStatus: String) -> FileStatus {
        let char = String(gitStatus.prefix(1))
        return FileStatus(rawValue: char) ?? .modified
    }
    
    var displayName: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .unmerged: return "Unmerged"
        case .typeChanged: return "Type Changed"
        }
    }
    
    var color: NSColor {
        switch self {
        case .modified: return .systemOrange
        case .added: return .systemGreen
        case .deleted: return .systemRed
        case .renamed: return .systemBlue
        case .copied: return .systemPurple
        case .untracked: return .systemGray
        case .unmerged: return .systemYellow
        case .typeChanged: return .systemTeal
        }
    }
    
    var icon: String {
        switch self {
        case .modified: return "pencil"
        case .added: return "plus"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .untracked: return "questionmark"
        case .unmerged: return "exclamationmark.triangle"
        case .typeChanged: return "arrow.triangle.2.circlepath"
        }
    }
}

struct ChangedFile: Identifiable, Hashable {
    let path: String
    let status: FileStatus
    var staged: Bool
    
    // Stable ID based on path and staged status
    var id: String {
        return "\(path)-\(staged ? "staged" : "unstaged")"
    }
    
    var filename: String {
        return (path as NSString).lastPathComponent
    }
    
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir + "/"
    }
    
    var icon: NSImage {
        return NSWorkspace.shared.icon(forFileType: (path as NSString).pathExtension)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(staged)
    }
    
    static func == (lhs: ChangedFile, rhs: ChangedFile) -> Bool {
        return lhs.path == rhs.path && lhs.staged == rhs.staged
    }
}
