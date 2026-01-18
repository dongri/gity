//
//  HistoryView.swift
//  GitY
//
//  History view - equivalent to PBGitHistoryController
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var repository: GitRepository
    let selection: SidebarSelection
    
    @State private var searchText: String = ""
    @State private var searchMode: SearchMode = .subject
    @State private var branchFilter: BranchFilterType = .all
    @State private var selectedCommit: GitCommit?
    @State private var diffContent: String = ""
    @State private var detailViewMode: DetailViewMode = .diff
    @State private var isLoadingDiff: Bool = false
    @State private var diffLoadTask: Task<Void, Never>?
    
    enum SearchMode: String, CaseIterable {
        case subject = "Subject"
        case author = "Author"
        case sha = "SHA"
    }
    
    enum DetailViewMode: String, CaseIterable {
        case diff = "Diff"
        case tree = "Tree"
    }
    
    private var filteredCommits: [GitCommit] {
        var commits = repository.commits
        
        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            commits = commits.filter { commit in
                switch searchMode {
                case .subject:
                    return commit.subject.lowercased().contains(query)
                case .author:
                    return commit.author.lowercased().contains(query) ||
                           commit.authorEmail.lowercased().contains(query)
                case .sha:
                    return commit.sha.lowercased().hasPrefix(query) ||
                           commit.shortSha.lowercased().hasPrefix(query)
                }
            }
        }
        
        return commits
    }
    
    /// Extract the GitRef from the current selection
    private var selectedGitRef: GitRef? {
        switch selection {
        case .branch(let ref), .remoteBranch(let ref), .tag(let ref):
            return ref
        default:
            return nil
        }
    }
    // Store the split ratio to maintain consistent sizing
    @State private var splitRatio: CGFloat = 0.55
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Commit list - takes majority of space
                VStack(spacing: 0) {
                    // Toolbar
                    HStack(spacing: 8) {
                        // Branch filter pills
                        Picker("Filter", selection: $branchFilter) {
                            Text("All").tag(BranchFilterType.all)
                            Text("Local").tag(BranchFilterType.localRemote)
                            Text(filterLabel).tag(BranchFilterType.selected)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        
                        Spacer()
                        
                        // Search
                        Picker("", selection: $searchMode) {
                            ForEach(SearchMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .frame(width: 80)
                        
                        TextField("🔍 Subject, Author, SHA", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    // Commit table
                    CommitTableView(
                        commits: filteredCommits,
                        selectedCommit: $selectedCommit,
                        hasMoreCommits: !repository.isInitializing && repository.hasMoreCommits,
                        isLoadingMore: repository.isLoadingMoreCommits,
                        onLoadMore: {
                            Task {
                                await repository.loadMoreCommitsForRef(selectedGitRef, filter: branchFilter)
                            }
                        }
                    )
                }
                .frame(height: geometry.size.height * splitRatio)
                
                // Resizable divider
                ResizableDivider(
                    totalHeight: geometry.size.height,
                    splitRatio: $splitRatio
                )
                
                // Commit detail view - fixed height area
                Group {
                    if let commit = selectedCommit {
                        CommitDetailView(
                            commit: commit,
                            diffContent: diffContent,
                            isLoadingDiff: isLoadingDiff,
                            viewMode: $detailViewMode
                        )
                    } else {
                        VStack {
                            Spacer()
                            Text("No file selected")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    }
                }
                .frame(height: geometry.size.height * (1 - splitRatio) - 8) // 8 for divider
            }
        }
        .onChange(of: branchFilter) { newFilter in
            repository.currentBranchFilter = newFilter
            // Only reload if we have a valid selection or filter is not .selected
            // This avoids double-loading when selection changes
            if newFilter != .selected || selectedGitRef != nil {
                Task {
                    await repository.loadCommitsForRef(selectedGitRef, filter: newFilter)
                }
            }
        }
        .onChange(of: selection) { newSelection in
            // Extract ref from the new selection directly
            let newRef: GitRef?
            switch newSelection {
            case .branch(let ref), .remoteBranch(let ref), .tag(let ref):
                newRef = ref
                // Set filter to selected for specific branch/tag
                if branchFilter != .selected {
                    branchFilter = .selected
                }
            default:
                newRef = nil
            }
            
            // Load commits for the selected ref
            Task {
                await repository.loadCommitsForRef(newRef, filter: .selected)
            }
        }
        .onChange(of: selectedCommit) { _ in
            loadDiffForSelectedCommit()
        }
        .onAppear {
            // Set filter to "selected" when viewing a specific branch/tag
            switch selection {
            case .branch, .remoteBranch, .tag:
                branchFilter = .selected
            default:
                break
            }
            Task {
                await repository.loadCommitsForRef(selectedGitRef, filter: branchFilter)
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) {
                if isLoadingDiff {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if !repository.commits.isEmpty {
                    Text("\(filteredCommits.count) commits loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadDiffForSelectedCommit() {
        // Cancel any previous diff loading task
        diffLoadTask?.cancel()
        
        guard let commit = selectedCommit else {
            diffContent = ""
            isLoadingDiff = false
            return
        }
        
        isLoadingDiff = true
        diffContent = "" // Clear immediately for responsiveness
        
        diffLoadTask = Task {
            let result = await repository.diffAsync(for: commit)
            
            // Check if task was cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    diffContent = result
                    isLoadingDiff = false
                }
            }
        }
    }
    
    private var filterLabel: String {
        switch selection {
        case .branch(let ref):
            return ref.name
        case .remoteBranch(let ref):
            return ref.displayName
        case .tag(let ref):
            return ref.name
        default:
            return repository.currentBranch?.name ?? "Selected"
        }
    }
}

// MARK: - Commit Table View

struct CommitTableView: View {
    let commits: [GitCommit]
    @Binding var selectedCommit: GitCommit?
    let hasMoreCommits: Bool
    let isLoadingMore: Bool
    let onLoadMore: () -> Void
    
    // Computed binding to avoid state sync issues
    private var selectionBinding: Binding<GitCommit.ID?> {
        Binding(
            get: { selectedCommit?.id },
            set: { newID in
                if let newID = newID {
                    selectedCommit = commits.first { $0.id == newID }
                } else {
                    selectedCommit = nil
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Table(commits, selection: selectionBinding) {
                TableColumn("Short S.") { commit in
                    HStack(spacing: 4) {
                        // Refs badges
                        ForEach(commit.refs, id: \.self) { ref in
                            RefBadge(ref: ref)
                        }
                        
                        Text(commit.shortSha)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        // Auto-load more when the last commit becomes visible
                        if commit.id == commits.last?.id && hasMoreCommits && !isLoadingMore {
                            onLoadMore()
                        }
                    }
                }
                .width(min: 80, ideal: 120)
                
                TableColumn("Subject", value: \.subject)
                    .width(min: 200, ideal: 400)
                
                TableColumn("Author", value: \.author)
                    .width(min: 100, ideal: 150)
                
                TableColumn("Date") { commit in
                    Text(commit.dateString)
                        .foregroundColor(.secondary)
                }
                .width(min: 120, ideal: 180)
            }
            
            // Loading indicator at bottom (shown during auto-load)
            if isLoadingMore && hasMoreCommits {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading more commits...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }
}

struct RefBadge: View {
    let ref: GitRef
    
    var body: some View {
        Text(ref.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var badgeColor: Color {
        switch ref.type {
        case .branch:
            return .blue
        case .remoteBranch:
            return .purple
        case .tag:
            return .orange
        case .head:
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Commit Detail View

struct CommitDetailView: View {
    let commit: GitCommit
    let diffContent: String
    let isLoadingDiff: Bool
    @Binding var viewMode: HistoryView.DetailViewMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Commit info header
            CommitInfoHeader(commit: commit)
            
            Divider()
            
            // View mode picker
            HStack {
                Picker("View", selection: $viewMode) {
                    ForEach(HistoryView.DetailViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                Spacer()
                
                if isLoadingDiff {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading diff...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Content
            switch viewMode {
            case .diff:
                if isLoadingDiff {
                    VStack {
                        Spacer()
                        ProgressView("Loading diff...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    DiffView(content: diffContent, filePath: nil)
                }
            case .tree:
                Text("Tree view coming soon")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct CommitInfoHeader: View {
    let commit: GitCommit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subject
            Text("Subject: \(commit.subject)")
                .font(.headline)
                .lineLimit(2)
            
            // Commit info
            HStack {
                Text("ID")
                    .foregroundColor(.secondary)
                Text(commit.sha)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            
            if !commit.parentSHAs.isEmpty {
                HStack {
                    Text("Parents")
                        .foregroundColor(.secondary)
                    ForEach(commit.parentSHAs, id: \.self) { sha in
                        Text(String(sha.prefix(7)))
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            HStack {
                Text("Author")
                    .foregroundColor(.secondary)
                Text("\(commit.author) <\(commit.authorEmail)>")
                Text("· \(commit.dateString)")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Resizable Divider

struct ResizableDivider: View {
    let totalHeight: CGFloat
    @Binding var splitRatio: CGFloat
    
    @State private var isDragging: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor : Color(nsColor: .separatorColor))
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newRatio = (value.location.y + totalHeight * splitRatio) / totalHeight
                        // Clamp to reasonable bounds (20% - 80%)
                        splitRatio = min(max(newRatio, 0.2), 0.8)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
