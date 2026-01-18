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
                        Picker("", selection: $branchFilter) {
                            Text("All").tag(BranchFilterType.all)
                            Text("Local").tag(BranchFilterType.localRemote)
                            Text(truncatedFilterLabel).tag(BranchFilterType.selected)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .pointingHandCursor()
                        
                        Spacer()
                        
                        // Search
                        Picker("", selection: $searchMode) {
                            ForEach(SearchMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .frame(width: 80)
                        .pointingHandCursor()
                        
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
                            repository: repository,
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
    
    private var truncatedFilterLabel: String {
        let label = filterLabel
        if label.count > 12 {
            return String(label.prefix(10)) + "..."
        }
        return label
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
            .pointingHandCursor()
            
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
    @ObservedObject var repository: GitRepository
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
                Picker("", selection: $viewMode) {
                    ForEach(HistoryView.DetailViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .pointingHandCursor()
                
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
                CommitTreeView(repository: repository, commit: commit)
            }
        }
    }
}

// MARK: - Commit Tree View

struct CommitTreeView: View {
    @ObservedObject var repository: GitRepository
    let commit: GitCommit
    
    @State private var treeNodes: [TreeNode] = []
    @State private var isLoading: Bool = true
    @State private var selectedFile: TreeEntry?
    @State private var fileContent: String = ""
    @State private var isLoadingContent: Bool = false
    @State private var searchText: String = ""
    @State private var fileCount: Int = 0
    
    private var filteredNodes: [TreeNode] {
        if searchText.isEmpty {
            return treeNodes
        }
        let query = searchText.lowercased()
        return filterNodes(treeNodes, matching: query)
    }
    
    var body: some View {
        HSplitView {
            // File tree
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                
                Divider()
                
                // File count
                HStack {
                    Text("\(fileCount) files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                
                // Tree list
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading tree...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if treeNodes.isEmpty {
                    VStack {
                        Spacer()
                        Text("No files")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredNodes) { node in
                                TreeNodeView(
                                    node: node,
                                    selectedFile: $selectedFile,
                                    depth: 0
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // File content
            VStack(spacing: 0) {
                if let file = selectedFile {
                    HStack {
                        Image(systemName: file.iconName)
                            .foregroundColor(iconColor(for: file))
                        Text(file.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    if isLoadingContent {
                        VStack {
                            Spacer()
                            ProgressView("Loading content...")
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        FileContentView(content: fileContent, filePath: file.path)
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Select a file to view its content")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
        .onAppear {
            loadTree()
        }
        .onChange(of: commit.sha) { _ in
            loadTree()
        }
        .onChange(of: selectedFile) { newFile in
            if let file = newFile {
                loadFileContent(file)
            }
        }
    }
    
    private func loadTree() {
        isLoading = true
        selectedFile = nil
        fileContent = ""
        
        Task {
            let entries = await repository.getTreeAsync(for: commit)
            await MainActor.run {
                treeNodes = TreeNode.buildTree(from: entries)
                fileCount = entries.count
                isLoading = false
            }
        }
    }
    
    private func loadFileContent(_ file: TreeEntry) {
        isLoadingContent = true
        fileContent = ""
        
        Task {
            let content = await repository.getFileContentAsync(commit: commit, path: file.path)
            await MainActor.run {
                fileContent = content
                isLoadingContent = false
            }
        }
    }
    
    private func filterNodes(_ nodes: [TreeNode], matching query: String) -> [TreeNode] {
        var result: [TreeNode] = []
        
        for node in nodes {
            if node.name.lowercased().contains(query) {
                result.append(node)
            } else if node.isDirectory {
                let filteredChildren = filterNodes(node.children, matching: query)
                if !filteredChildren.isEmpty {
                    let filteredNode = TreeNode(
                        name: node.name,
                        path: node.path,
                        entry: node.entry,
                        isDirectory: node.isDirectory,
                        children: filteredChildren
                    )
                    filteredNode.isExpanded = true
                    result.append(filteredNode)
                }
            }
        }
        
        return result
    }
    
    private func iconColor(for file: TreeEntry) -> Color {
        switch file.iconColor {
        case "orange": return .orange
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "red": return .red
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Tree Node View

struct TreeNodeView: View {
    @ObservedObject var node: TreeNode
    @Binding var selectedFile: TreeEntry?
    let depth: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }
                
                // Expand/collapse button for directories
                if node.isDirectory {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            node.isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12)
                }
                
                // Icon
                Image(systemName: node.isDirectory ? (node.isExpanded ? "folder.fill" : "folder") : (node.entry?.iconName ?? "doc"))
                    .font(.system(size: 14))
                    .foregroundColor(node.isDirectory ? .blue : nodeIconColor)
                    .frame(width: 18)
                
                // Name
                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Spacer()
                
                // Size for files
                if !node.isDirectory, let entry = node.entry {
                    Text(entry.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        node.isExpanded.toggle()
                    }
                } else if let entry = node.entry {
                    selectedFile = entry
                }
            }
            .pointingHandCursor()
            
            // Children
            if node.isExpanded {
                ForEach(node.children) { child in
                    TreeNodeView(
                        node: child,
                        selectedFile: $selectedFile,
                        depth: depth + 1
                    )
                }
            }
        }
    }
    
    private var isSelected: Bool {
        if let selected = selectedFile, let entry = node.entry {
            return selected.path == entry.path
        }
        return false
    }
    
    private var nodeIconColor: Color {
        guard let entry = node.entry else { return .secondary }
        switch entry.iconColor {
        case "orange": return .orange
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "red": return .red
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - File Content View

struct FileContentView: View {
    let content: String
    let filePath: String
    
    // Pagination settings
    private let initialLineCount: Int = 500
    private let loadMoreLineCount: Int = 500
    
    @State private var visibleLineCount: Int = 500
    @State private var lines: [String] = []
    @State private var totalLineCount: Int = 0
    
    private var displayedLines: ArraySlice<String> {
        lines.prefix(visibleLineCount)
    }
    
    private var hasMoreLines: Bool {
        visibleLineCount < totalLineCount
    }
    
    private var remainingLineCount: Int {
        max(0, totalLineCount - visibleLineCount)
    }
    
    private var isBinaryFile: Bool {
        let binaryExtensions = ["png", "jpg", "jpeg", "gif", "ico", "webp", "pdf", "zip", "tar", "gz", "rar", "7z", "mp3", "mp4", "mov", "avi", "mkv", "wav", "aac"]
        let ext = (filePath as NSString).pathExtension.lowercased()
        return binaryExtensions.contains(ext) || content.contains("\0")
    }
    
    var body: some View {
        if isBinaryFile {
            VStack {
                Spacer()
                Image(systemName: "doc.zipper")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Binary file - cannot display")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(displayedLines.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                    .padding(.trailing, 12)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                
                                Text(line.isEmpty ? " " : line)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Load more button
                        if hasMoreLines {
                            loadMoreButton(width: geometry.size.width)
                        }
                    }
                    .padding(4)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                parseContent()
            }
            .onChange(of: content) { _ in
                parseContent()
            }
        }
    }
    
    private func loadMoreButton(width: CGFloat) -> some View {
        Button(action: loadMore) {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Load more lines")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("\(remainingLineCount.formatted()) lines remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                Spacer()
            }
            .frame(width: max(width - 16, 200))
            .background(Color.accentColor.opacity(0.2))
            .cornerRadius(8)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
    
    private func parseContent() {
        lines = content.components(separatedBy: "\n")
        totalLineCount = lines.count
        visibleLineCount = min(initialLineCount, totalLineCount)
    }
    
    private func loadMore() {
        visibleLineCount = min(visibleLineCount + loadMoreLineCount, totalLineCount)
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
