//
//  StageView.swift
//  GitY
//
//  Stage view - equivalent to PBGitCommitController
//

import SwiftUI
import Combine

struct StageView: View {
    @ObservedObject var repository: GitRepository
    @State private var commitMessage: String = ""
    @State private var isAmend: Bool = false
    @State private var selectedUnstagedFile: ChangedFile?
    @State private var selectedStagedFile: ChangedFile?
    @State private var diffContent: String = ""
    @State private var isCommitting: Bool = false
    @State private var isLoadingDiff: Bool = false
    @State private var diffLoadTask: Task<Void, Never>?
    @FocusState private var isCommitMessageFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Diff view at top
            ZStack {
                DiffView(content: diffContent, filePath: selectedFile?.path)
                    .frame(minHeight: 200)
                    .opacity(isLoadingDiff ? 0.3 : 1.0)
                
                if isLoadingDiff {
                    ProgressView("Loading diff...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            
            Divider()
            
            // Bottom section: File lists and commit message
            HStack(spacing: 0) {
                // Unstaged changes
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Unstaged Changes")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !repository.unstagedFiles.isEmpty {
                            Button("Stage All") {
                                stageAll()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .pointingHandCursor()
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    FileListView(
                        files: repository.unstagedFiles,
                        selectedFile: $selectedUnstagedFile,
                        onDoubleClick: { file in
                            stageFile(file)
                        },
                        onDiscard: { file in
                            discardFile(file)
                        }
                    )
                }
                .frame(minWidth: 200)
                
                Divider()
                
                // Commit message
                VStack(alignment: .leading, spacing: 0) {
                    Text("Commit Message")
                        .font(.headline)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                    
                    TextEditor(text: $commitMessage)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .focused($isCommitMessageFocused)
                    
                    HStack {
                        Toggle("Amend", isOn: $isAmend)
                            .toggleStyle(.checkbox)
                            .pointingHandCursor()
                        
                        Spacer()
                        
                        Button("Commit") {
                            commitChanges()
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .pointingHandCursor()
                        .disabled(!canCommit)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .frame(minWidth: 250)
                
                Divider()
                
                // Staged changes
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Staged Changes")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !repository.stagedFiles.isEmpty {
                            Button("Unstage All") {
                                unstageAll()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .pointingHandCursor()
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    FileListView(
                        files: repository.stagedFiles,
                        selectedFile: $selectedStagedFile,
                        onDoubleClick: { file in
                            unstageFile(file)
                        }
                    )
                }
                .frame(minWidth: 200)
            }
            .frame(height: 280)
        }
        .onChange(of: selectedUnstagedFile) { file in
            if let file = file {
                selectedStagedFile = nil
                diffLoadTask?.cancel()
                loadDiffAsync(for: file)
            } else if selectedStagedFile == nil {
                diffLoadTask?.cancel()
                isLoadingDiff = false
                diffContent = ""
            }
        }
        .onChange(of: selectedStagedFile) { file in
            if let file = file {
                selectedUnstagedFile = nil
                diffLoadTask?.cancel()
                loadDiffAsync(for: file)
            } else if selectedUnstagedFile == nil {
                diffLoadTask?.cancel()
                isLoadingDiff = false
                diffContent = ""
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                if isLoadingDiff {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
        }
    }
    
    private var canCommit: Bool {
        commitMessage.count >= 3 && !repository.stagedFiles.isEmpty && !isCommitting
    }
    
    private var selectedFile: ChangedFile? {
        selectedUnstagedFile ?? selectedStagedFile
    }
    
    private func loadDiffAsync(for file: ChangedFile) {
        isLoadingDiff = true
        diffContent = ""
        
        diffLoadTask = Task {
            let result = await repository.diffAsync(for: file)
            
            if !Task.isCancelled {
                await MainActor.run {
                    diffContent = result
                    isLoadingDiff = false
                }
            }
        }
    }
    
    private func stageFile(_ file: ChangedFile) {
        Task {
            try? await repository.stage(files: [file])
        }
    }
    
    private func unstageFile(_ file: ChangedFile) {
        Task {
            try? await repository.unstage(files: [file])
        }
    }
    
    private func stageAll() {
        Task {
            try? await repository.stage(files: repository.unstagedFiles)
        }
    }
    
    private func unstageAll() {
        Task {
            try? await repository.unstage(files: repository.stagedFiles)
        }
    }
    
    private func commitChanges() {
        isCommitting = true
        Task {
            do {
                try await repository.commit(message: commitMessage, amend: isAmend)
                await MainActor.run {
                    commitMessage = ""
                    isAmend = false
                    isCommitting = false
                }
            } catch {
                await MainActor.run {
                    isCommitting = false
                    let alert = NSAlert()
                    alert.messageText = "Commit Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
    
    private func discardFile(_ file: ChangedFile) {
        let alert = NSAlert()
        alert.messageText = "Discard Changes?"
        alert.informativeText = "Are you sure you want to discard changes to '\(file.filename)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                try? await repository.discard(files: [file])
            }
        }
    }
}

// MARK: - File List View

struct FileListView: View {
    let files: [ChangedFile]
    @Binding var selectedFile: ChangedFile?
    let onDoubleClick: (ChangedFile) -> Void
    var onDiscard: ((ChangedFile) -> Void)? = nil
    
    var body: some View {
        List(files, id: \.id, selection: Binding(
            get: { selectedFile?.id },
            set: { newID in
                selectedFile = files.first { $0.id == newID }
            }
        )) { file in
            FileRow(file: file, isSelected: selectedFile?.id == file.id)
                .tag(file.id)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    onDoubleClick(file)
                })
                .simultaneousGesture(TapGesture().onEnded {
                    selectedFile = file
                })
                .pointingHandCursor()
                .contextMenu {
                    if let onDiscard = onDiscard {
                        Button("Discard Changes") {
                            onDiscard(file)
                        }
                    }
                }
        }
        .listStyle(.plain)
    }
}

struct FileRow: View {
    let file: ChangedFile
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(Color(nsColor: file.status.color))
                .frame(width: 8, height: 8)
            
            // File icon
            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 16, height: 16)
            
            // File name
            Text(file.filename)
                .lineLimit(1)
            
            Spacer()
            
            // Directory
            if !file.directory.isEmpty {
                Text(file.directory)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}
