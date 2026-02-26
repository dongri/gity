//
//  SubmoduleDetailView.swift
//  GitY
//
//  Submodule detail view
//

import SwiftUI

struct SubmoduleDetailView: View {
    @ObservedObject var repository: GitRepository
    let submodule: GitSubmodule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(submodule.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Path: \(submodule.path)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("SHA: \(submodule.sha)")
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
                    openSubmodule()
                } label: {
                    Label("Open Submodule", systemImage: "folder")
                }
                .pointingHandCursor()
                
                Button {
                    Task {
                        updateSubmodule()
                    }
                } label: {
                    Label("Update", systemImage: "arrow.clockwise")
                }
                .pointingHandCursor()
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func openSubmodule() {
        let submodulePath = repository.workingDirectory.appendingPathComponent(submodule.path)
        NotificationCenter.default.post(name: .openRepositoryURL, object: submodulePath)
    }
    
    private func updateSubmodule() {
        _ = repository.runGit(["submodule", "update", "--init", submodule.path])
    }
}
