//
//  StashDetailView.swift
//  GitY
//
//  Stash detail view
//

import SwiftUI

struct StashDetailView: View {
    @ObservedObject var repository: GitRepository
    let stash: GitStash
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(stash.shortName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(stash.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("SHA: \(stash.sha)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    Task {
                        try? await repository.stashApply(stash: stash)
                    }
                } label: {
                    Label("Apply", systemImage: "arrow.down.doc")
                }
                
                Button {
                    Task {
                        try? await repository.stashPop(stash: stash)
                    }
                } label: {
                    Label("Pop", systemImage: "arrow.up.doc")
                }
                
                Button(role: .destructive) {
                    Task {
                        try? await repository.stashDrop(stash: stash)
                    }
                } label: {
                    Label("Drop", systemImage: "trash")
                }
                
                Spacer()
            }
            
            // Stash diff
            Text("Changes in this stash:")
                .font(.headline)
            
            DiffView(content: stashDiff, filePath: nil)
            
            Spacer()
        }
        .padding()
    }
    
    private var stashDiff: String {
        return repository.runGit(["stash", "show", "-p", "stash@{\(stash.index)}"])
    }
}
