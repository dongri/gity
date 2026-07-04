//
//  CommitData.swift
//  GitY
//
//  Created by Sergey on 09.03.2026.
//

struct CommitData {
    let commit: GitCommit
    
    private let searchIndexes: CommitSearchIndex
    
    init(commit: GitCommit) {
        self.commit = commit
        self.searchIndexes = CommitSearchIndex(commit)
    }
    
    func isMatches(_ keyword: String) -> Bool {
        searchIndexes.isMatches(keyword)
    }
}

struct CommitSearchIndex {
    private let fields: [String]
    
    init(_ commit: GitCommit) {
        fields = [
            commit.subject,
            commit.author,
            commit.authorEmail,
            commit.sha,
            commit.shortSha
        ]
            .map { $0.lowercased() }
    }
    
    func isMatches(_ keyword: String) -> Bool {
        if keyword.isEmpty {
            return true
        }
        
        for f in fields {
            if f.contains(keyword) {
                return true
            }
        }
        return false
    }
}
