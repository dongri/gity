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
    @State private var selectedUnstagedFileIDs: Set<String> = []
    @State private var selectedStagedFileIDs: Set<String> = []
    @State private var diffContent: String = ""
    @State private var isCommitting: Bool = false
    @State private var isLoadingDiff: Bool = false
    @State private var diffLoadTask: Task<Void, Never>?
    @FocusState private var isCommitMessageFocused: Bool
    @ObservedObject private var llmService = LocalLLMService.shared
    
    // Helper computed properties for selected files
    private var selectedUnstagedFiles: [ChangedFile] {
        repository.unstagedFiles.filter { selectedUnstagedFileIDs.contains($0.id) }
    }
    
    private var selectedStagedFiles: [ChangedFile] {
        repository.stagedFiles.filter { selectedStagedFileIDs.contains($0.id) }
    }
    
    private var isMultipleSelection: Bool {
        selectedUnstagedFileIDs.count > 1 || selectedStagedFileIDs.count > 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Diff view at top
            ZStack {
                if isMultipleSelection {
                    // Multiple selection - don't show diff
                    VStack {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("\(selectedUnstagedFileIDs.count + selectedStagedFileIDs.count) files selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Double-click to stage/unstage all selected files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                } else {
                    DiffView(content: diffContent, filePath: selectedFile?.path)
                        .frame(minHeight: 200)
                        .opacity(isLoadingDiff ? 0.3 : 1.0)
                }
                
                if isLoadingDiff && !isMultipleSelection {
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
                        selectedFileIDs: $selectedUnstagedFileIDs,
                        onDoubleClick: {
                            stageSelectedUnstagedFiles()
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
                    HStack {
                        Text("Commit Message")
                            .font(.headline)
                        
                        Spacer()
                        
                        if llmService.isDownloading {
                            Text("Downloading Model: \(Int(llmService.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if llmService.isGenerating {
                            Text("Generating...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                if llmService.isModelDownloaded(id: llmService.selectedModelId) {
                                    Button(action: {
                                        generateAICommitMessage()
                                    }) {
                                        Label("Generate", systemImage: "sparkles")
                                            .labelStyle(.titleAndIcon)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .pointingHandCursor()
                                    .help("Generate commit message from staged changes")
                                    
                                    // Settings button (always shown)
                                    Button(action: {
                                        openSettings()
                                    }) {
                                        Image(systemName: "gearshape")
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .pointingHandCursor()
                                    .help("Select AI Model")
                                } else {
                                    Button(action: {
                                        openSettings()
                                    }) {
                                        Label("Download AI Model", systemImage: "arrow.down.circle")
                                            .labelStyle(.titleAndIcon)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .pointingHandCursor()
                                    .help("Go to Settings to download an AI model")
                                }
                            }
                        }
                    }
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
                        selectedFileIDs: $selectedStagedFileIDs,
                        onDoubleClick: {
                            unstageSelectedStagedFiles()
                        }
                    )
                }
                .frame(minWidth: 200)
            }
            .frame(height: 280)
        }
        .onChange(of: selectedUnstagedFileIDs) { newIDs in
            if !newIDs.isEmpty {
                selectedStagedFileIDs = []
                diffLoadTask?.cancel()
                
                // Only load diff for single selection
                if newIDs.count == 1, let fileID = newIDs.first,
                   let file = repository.unstagedFiles.first(where: { $0.id == fileID }) {
                    loadDiffAsync(for: file)
                } else {
                    isLoadingDiff = false
                    diffContent = ""
                }
            } else if selectedStagedFileIDs.isEmpty {
                diffLoadTask?.cancel()
                isLoadingDiff = false
                diffContent = ""
            }
        }
        .onChange(of: selectedStagedFileIDs) { newIDs in
            if !newIDs.isEmpty {
                selectedUnstagedFileIDs = []
                diffLoadTask?.cancel()
                
                // Only load diff for single selection
                if newIDs.count == 1, let fileID = newIDs.first,
                   let file = repository.stagedFiles.first(where: { $0.id == fileID }) {
                    loadDiffAsync(for: file)
                } else {
                    isLoadingDiff = false
                    diffContent = ""
                }
            } else if selectedUnstagedFileIDs.isEmpty {
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
        .onChange(of: llmService.generatedMessage) { newMessage in
            if !newMessage.isEmpty {
                commitMessage = newMessage
            }
        }
        .onChange(of: llmService.errorMessage) { errorMsg in
            if let errorMsg = errorMsg {
                // We need to run this on main thread, but onChange is already on main actor context?
                // runModal blocks, so usually safer to use alert(item:) modifier in SwiftUI,
                // but for now keeping consistent with other parts of the app using NSAlert.runModal()
                // Be careful not to block UI updates.
                // Better approach for SwiftUI is to use .alert()
                 let alert = NSAlert()
                 alert.messageText = "AI Generation Error"
                 alert.informativeText = errorMsg
                 alert.runModal()
            }
        }
    }
    
    private var canCommit: Bool {
        commitMessage.count >= 3 && !repository.stagedFiles.isEmpty && !isCommitting
    }
    
    private var selectedFile: ChangedFile? {
        if selectedUnstagedFileIDs.count == 1, let id = selectedUnstagedFileIDs.first {
            return repository.unstagedFiles.first { $0.id == id }
        }
        if selectedStagedFileIDs.count == 1, let id = selectedStagedFileIDs.first {
            return repository.stagedFiles.first { $0.id == id }
        }
        return nil
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
    
    private func stageSelectedUnstagedFiles() {
        let filesToStage = selectedUnstagedFiles
        guard !filesToStage.isEmpty else { return }
        
        Task {
            try? await repository.stage(files: filesToStage)
            await MainActor.run {
                selectedUnstagedFileIDs = []
            }
        }
    }
    
    private func unstageSelectedStagedFiles() {
        let filesToUnstage = selectedStagedFiles
        guard !filesToUnstage.isEmpty else { return }
        
        Task {
            try? await repository.unstage(files: filesToUnstage)
            await MainActor.run {
                selectedStagedFileIDs = []
            }
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
    
    private func generateAICommitMessage() {
        if !llmService.isModelDownloaded(id: llmService.selectedModelId) {
            // Should not happen via UI, but safe check
            openSettings()
            return
        }
        
        Task {
            let diff = await repository.diffStaged()
            if diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "No Staged Changes"
                    alert.informativeText = "Please stage files to generate a commit message."
                    alert.runModal()
                 }
                return
            }
            
            // Limit diff size to avoid context window overflow
            let maxDiffLength = 6000
            let truncatedDiff = diff.count > maxDiffLength ? String(diff.prefix(maxDiffLength)) + "\n...(truncated)" : diff
            
            await llmService.generateCommitMessage(diff: truncatedDiff)
        }
    }
    
    private func openSettings() {
        // Set a flag to open AI settings so PreferencesView can check it on appear
        UserDefaults.standard.set(true, forKey: "OpenAISettingsOnLoad")
        
        // Try standard selectors first
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        
        // If that fails (or as a backup), try to find the menu item with Cmd+, shortcut
        if let menu = NSApp.mainMenu {
            for item in menu.items {
                if let submenu = item.submenu {
                    for subitem in submenu.items {
                        // Check for Cmd+, shortcut
                        if subitem.keyEquivalent == "," && subitem.keyEquivalentModifierMask.contains(.command) {
                            if let action = subitem.action {
                                NSApp.sendAction(action, to: subitem.target, from: subitem)
                                return
                            }
                        }
                    }
                }
            }
        }
        
        // Fallback Notification (only works if window is already open)
        NotificationCenter.default.post(name: .openAISettings, object: nil)
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

struct FileListView: NSViewRepresentable {
    let files: [ChangedFile]
    @Binding var selectedFileIDs: Set<String>
    let onDoubleClick: () -> Void
    var onDiscard: ((ChangedFile) -> Void)? = nil
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.width = 300
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.target = context.coordinator
        
        // Add menu for right-click
        if onDiscard != nil {
            let menu = NSMenu()
            let discardItem = NSMenuItem(title: "Discard Changes", action: #selector(Coordinator.handleDiscard(_:)), keyEquivalent: "")
            discardItem.target = context.coordinator
            menu.addItem(discardItem)
            tableView.menu = menu
        }
        
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        
        let oldFiles = context.coordinator.files
        let filesChanged = files.map { $0.id } != oldFiles.map { $0.id }
        
        context.coordinator.files = files
        context.coordinator.selectedFileIDs = selectedFileIDs
        context.coordinator.onDoubleClick = onDoubleClick
        context.coordinator.onDiscard = onDiscard
        context.coordinator.updateSelection = { newSelection in
            // Use binding directly - this is a struct so no weak reference needed
            DispatchQueue.main.async {
                self.selectedFileIDs = newSelection
            }
        }
        
        // Only reload if files changed
        if filesChanged {
            tableView.reloadData()
        }
        
        // Restore selection only if it doesn't match current
        let selectedIndices = IndexSet(files.enumerated().compactMap { index, file in
            selectedFileIDs.contains(file.id) ? index : nil
        })
        
        if tableView.selectedRowIndexes != selectedIndices {
            context.coordinator.isUpdatingSelection = true
            tableView.selectRowIndexes(selectedIndices, byExtendingSelection: false)
            context.coordinator.isUpdatingSelection = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(files: files, selectedFileIDs: selectedFileIDs, onDoubleClick: onDoubleClick, onDiscard: onDiscard)
    }
    
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var files: [ChangedFile]
        var selectedFileIDs: Set<String>
        var onDoubleClick: () -> Void
        var onDiscard: ((ChangedFile) -> Void)?
        var updateSelection: ((Set<String>) -> Void)?
        weak var tableView: NSTableView?
        var isUpdatingSelection = false
        
        init(files: [ChangedFile], selectedFileIDs: Set<String>, onDoubleClick: @escaping () -> Void, onDiscard: ((ChangedFile) -> Void)?) {
            self.files = files
            self.selectedFileIDs = selectedFileIDs
            self.onDoubleClick = onDoubleClick
            self.onDiscard = onDiscard
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            files.count
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let file = files[row]
            
            let cellView = NSTableCellView()
            cellView.identifier = NSUserInterfaceItemIdentifier("FileCell")
            
            let stackView = NSStackView()
            stackView.orientation = .horizontal
            stackView.spacing = 8
            stackView.alignment = .centerY
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Status indicator
            let statusView = NSView()
            statusView.wantsLayer = true
            statusView.layer?.backgroundColor = file.status.color.cgColor
            statusView.layer?.cornerRadius = 4
            statusView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                statusView.widthAnchor.constraint(equalToConstant: 8),
                statusView.heightAnchor.constraint(equalToConstant: 8)
            ])
            
            // File icon
            let iconView = NSImageView(image: file.icon)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16)
            ])
            
            // File name
            let nameLabel = NSTextField(labelWithString: file.filename)
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            // Directory
            let dirLabel = NSTextField(labelWithString: file.directory)
            dirLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            dirLabel.textColor = .secondaryLabelColor
            dirLabel.lineBreakMode = .byTruncatingHead
            dirLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            stackView.addArrangedSubview(statusView)
            stackView.addArrangedSubview(iconView)
            stackView.addArrangedSubview(nameLabel)
            stackView.addArrangedSubview(dirLabel)
            
            cellView.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                stackView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isUpdatingSelection else { return }
            guard let tableView = notification.object as? NSTableView else { return }
            let selectedRows = tableView.selectedRowIndexes
            var newSelection = Set<String>()
            for row in selectedRows {
                if row < files.count {
                    newSelection.insert(files[row].id)
                }
            }
            updateSelection?(newSelection)
        }
        
        @objc func handleDoubleClick(_ sender: NSTableView) {
            if sender.clickedRow >= 0 {
                onDoubleClick()
            }
        }
        
        @objc func handleDiscard(_ sender: NSMenuItem) {
            guard let tableView = tableView, tableView.clickedRow >= 0 && tableView.clickedRow < files.count else { return }
            let file = files[tableView.clickedRow]
            onDiscard?(file)
        }
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
