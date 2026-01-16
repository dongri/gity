//
//  GitCommit.swift
//  GitY
//
//  Git commit model
//

import Foundation

struct GitCommit: Identifiable, Hashable {
    let id = UUID()
    let sha: String
    let shortSha: String
    let subject: String
    let author: String
    let authorEmail: String
    let date: Date
    let parentSHAs: [String]
    var refs: [GitRef]
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    static func from(logLine: String) -> GitCommit? {
        let parts = logLine.components(separatedBy: "|")
        guard parts.count >= 6 else { return nil }
        
        let sha = parts[0]
        let shortSha = parts[1]
        let subject = parts[2]
        let author = parts[3]
        let email = parts[4]
        let dateString = parts[5]
        let parents = parts.count > 6 ? parts[6].components(separatedBy: " ").filter { !$0.isEmpty } : []
        let refNames = parts.count > 7 ? parts[7] : ""
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: dateString) ?? Date()
        
        // Parse refs
        var refs: [GitRef] = []
        if !refNames.isEmpty {
            let refParts = refNames.components(separatedBy: ", ")
            for refPart in refParts {
                let cleaned = refPart.trimmingCharacters(in: .whitespaces)
                if cleaned.hasPrefix("HEAD -> ") {
                    let branchName = String(cleaned.dropFirst(8))
                    refs.append(GitRef(name: branchName, type: .branch, sha: sha))
                } else if cleaned.hasPrefix("tag: ") {
                    let tagName = String(cleaned.dropFirst(5))
                    refs.append(GitRef(name: tagName, type: .tag, sha: sha))
                } else if cleaned.contains("/") {
                    refs.append(GitRef(name: cleaned, type: .remoteBranch, sha: sha))
                } else if cleaned != "HEAD" {
                    refs.append(GitRef(name: cleaned, type: .branch, sha: sha))
                }
            }
        }
        
        return GitCommit(
            sha: sha,
            shortSha: shortSha,
            subject: subject,
            author: author,
            authorEmail: email,
            date: date,
            parentSHAs: parents,
            refs: refs
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(sha)
    }
    
    static func == (lhs: GitCommit, rhs: GitCommit) -> Bool {
        return lhs.sha == rhs.sha
    }
}
