//
//  TreeEntry.swift
//  GitY
//
//  Model for git tree entries (files and directories at a commit)
//

import Foundation

struct TreeEntry: Identifiable, Hashable {
    var id: String { path }
    let mode: String
    let type: EntryType
    let path: String
    let size: Int
    
    enum EntryType: String {
        case file
        case directory
    }
    
    /// Get the filename from the path
    var filename: String {
        (path as NSString).lastPathComponent
    }
    
    /// Get the parent directory path
    var parentPath: String {
        (path as NSString).deletingLastPathComponent
    }
    
    /// Get file extension
    var fileExtension: String {
        (path as NSString).pathExtension.lowercased()
    }
    
    /// Get human-readable size
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    /// Get icon name based on file type
    var iconName: String {
        if type == .directory {
            return "folder.fill"
        }
        
        switch fileExtension {
        case "swift":
            return "swift"
        case "md", "markdown":
            return "doc.text"
        case "json", "yml", "yaml", "xml", "plist":
            return "doc.badge.gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico", "webp":
            return "photo"
        case "mp3", "wav", "aac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "zip", "tar", "gz", "rar", "7z":
            return "archivebox"
        case "pdf":
            return "doc.richtext"
        case "sh", "bash", "zsh":
            return "terminal"
        case "py":
            return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "jsx", "tsx":
            return "curlybraces"
        case "html", "css", "scss", "sass":
            return "globe"
        case "go":
            return "chevron.left.forwardslash.chevron.right"
        case "rs":
            return "gearshape"
        case "c", "cpp", "h", "hpp", "m", "mm":
            return "c.circle"
        case "java", "kt", "kts":
            return "cup.and.saucer"
        case "rb":
            return "diamond"
        case "sql", "db", "sqlite":
            return "cylinder"
        case "txt", "log":
            return "doc.text"
        case "gitignore", "gitattributes":
            return "eye.slash"
        case "license":
            return "checkmark.seal"
        case "lock":
            return "lock"
        default:
            return "doc"
        }
    }
    
    /// Get icon color based on file type
    var iconColor: String {
        switch fileExtension {
        case "swift":
            return "orange"
        case "py":
            return "blue"
        case "js", "ts", "jsx", "tsx":
            return "yellow"
        case "html":
            return "orange"
        case "css", "scss", "sass":
            return "blue"
        case "json", "yml", "yaml":
            return "green"
        case "md", "markdown":
            return "gray"
        case "go":
            return "cyan"
        case "rs":
            return "orange"
        case "rb":
            return "red"
        default:
            return "secondary"
        }
    }
}

// MARK: - Tree Node for hierarchical display
class TreeNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let entry: TreeEntry?
    let isDirectory: Bool
    @Published var children: [TreeNode]
    @Published var isExpanded: Bool = false
    
    init(name: String, path: String, entry: TreeEntry? = nil, isDirectory: Bool, children: [TreeNode] = []) {
        self.name = name
        self.path = path
        self.entry = entry
        self.isDirectory = isDirectory
        self.children = children
    }
    
    /// Build tree structure from flat list of TreeEntry
    static func buildTree(from entries: [TreeEntry]) -> [TreeNode] {
        var rootChildren: [String: TreeNode] = [:]
        
        for entry in entries {
            let components = entry.path.components(separatedBy: "/")
            var currentPath = ""
            var currentLevel = rootChildren
            
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                
                if let existing = currentLevel[component] {
                    if !isLast {
                        currentLevel = Dictionary(uniqueKeysWithValues: existing.children.map { ($0.name, $0) })
                    }
                } else {
                    let node: TreeNode
                    if isLast {
                        // This is the file entry
                        node = TreeNode(
                            name: component,
                            path: currentPath,
                            entry: entry,
                            isDirectory: entry.type == .directory
                        )
                    } else {
                        // This is an intermediate directory
                        node = TreeNode(
                            name: component,
                            path: currentPath,
                            isDirectory: true
                        )
                    }
                    
                    // Add to parent
                    if currentPath == component {
                        rootChildren[component] = node
                    } else {
                        // Find parent and add
                        let parentPath = (currentPath as NSString).deletingLastPathComponent
                        if let parent = findNode(path: parentPath, in: Array(rootChildren.values)) {
                            if !parent.children.contains(where: { $0.name == component }) {
                                parent.children.append(node)
                            }
                        }
                    }
                    
                    if !isLast {
                        currentLevel = Dictionary(uniqueKeysWithValues: node.children.map { ($0.name, $0) })
                    }
                }
            }
        }
        
        // Sort children: directories first, then alphabetically
        return sortNodes(Array(rootChildren.values))
    }
    
    private static func findNode(path: String, in nodes: [TreeNode]) -> TreeNode? {
        for node in nodes {
            if node.path == path {
                return node
            }
            if let found = findNode(path: path, in: node.children) {
                return found
            }
        }
        return nil
    }
    
    private static func sortNodes(_ nodes: [TreeNode]) -> [TreeNode] {
        let sorted = nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        
        for node in sorted {
            node.children = sortNodes(node.children)
        }
        
        return sorted
    }
}
