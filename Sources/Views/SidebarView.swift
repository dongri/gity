//
//  SidebarView.swift
//  GitY
//
//  Sidebar view - equivalent to PBGitSidebarController
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var repository: GitRepository
    @Binding var selection: SidebarSelection
    
    // Default: Tags collapsed to avoid performance issues
    @State private var expandedSections: Set<String> = ["homepage", "branches", "remotes"]
    
    // Track expanded state for each remote (to avoid DisclosureGroup animation bug)
    @State private var expandedRemotes: Set<String> = []
    
    // Diff comparison sheet
    @State private var showDiffSheet: Bool = false
    @State private var diffCompareRef: GitRef? = nil
    @State private var diffContent: String = ""
    @State private var isLoadingDiff: Bool = false
    
    var body: some View {
        List(selection: $selection) {
            // Homepage section - always visible
            Section {
                SidebarItem(
                    title: "Stage",
                    icon: .system("square.and.pencil"),
                    badge: stageBadge,
                    isSelected: isStageSelected
                )
                .tag(SidebarSelection.stage)
            } header: {
                SectionHeader(title: "HOMEPAGE", isExpanded: expandedSections.contains("homepage")) {
                    toggleSection("homepage")
                }
            }
            
            // Loading indicator for refs
            if repository.isLoadingRefs && repository.branches.isEmpty {
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Branches section
            if !repository.branches.isEmpty || repository.isLoadingRefs {
                Section {
                    if expandedSections.contains("branches") {
                        ForEach(repository.branches, id: \.self) { branch in
                            SidebarItem(
                                title: branch.name,
//                                icon: .system("arrow.triangle.branch"),
                                icon: .local("git.branch"),
                                isCurrent: branch.name == repository.currentBranch?.name
                            )
                            .tag(SidebarSelection.branch(branch))
                            .contextMenu {
                                branchContextMenu(for: branch)
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "BRANCHES",
                        isExpanded: expandedSections.contains("branches"),
                        isLoading: repository.isLoadingRefs && repository.branches.isEmpty
                    ) {
                        toggleSection("branches")
                    }
                }
            }
            
            // Remotes section
            if !repository.remotes.isEmpty {
                Section {
                    if expandedSections.contains("remotes") {
                        ForEach(repository.remotes, id: \.self) { remote in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedRemotes.contains(remote) },
                                    set: { newValue in
                                        DispatchQueue.main.async {
                                            var transaction = Transaction()
                                            transaction.disablesAnimations = true
                                            withTransaction(transaction) {
                                                if newValue {
                                                    expandedRemotes.insert(remote)
                                                } else {
                                                    expandedRemotes.remove(remote)
                                                }
                                            }
                                        }
                                    }
                                )
                            ) {
                                ForEach(remoteBranches(for: remote), id: \.self) { branch in
                                    SidebarItem(
                                        title: branch.displayName,
                                        icon: .system("arrow.triangle.branch")
                                    )
                                    .tag(SidebarSelection.remoteBranch(branch))
                                    .contextMenu {
                                        remoteBranchContextMenu(for: branch)
                                    }
                                }
                            } label: {
                                Label(remote, systemImage: "externaldrive.connected.to.line.below")
                                    .contentShape(Rectangle())
                                    .pointingHandCursor()
                                    .onTapGesture {
                                        DispatchQueue.main.async {
                                            var transaction = Transaction()
                                            transaction.disablesAnimations = true
                                            withTransaction(transaction) {
                                                if expandedRemotes.contains(remote) {
                                                    expandedRemotes.remove(remote)
                                                } else {
                                                    expandedRemotes.insert(remote)
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "REMOTES", isExpanded: expandedSections.contains("remotes")) {
                        toggleSection("remotes")
                    }
                }
            }
            
            // Tags section (collapsed by default, lazy loading for performance)
            if !repository.tags.isEmpty || repository.totalTagCount > 0 || repository.isLoadingTags {
                Section {
                    if expandedSections.contains("tags") {
                        if repository.isLoadingTags && repository.tags.isEmpty {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading tags...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(repository.tags, id: \.self) { tag in
                                SidebarItem(
                                    title: tag.name,
                                    icon: .system("tag")
                                )
                                .tag(SidebarSelection.tag(tag))
                                .contextMenu {
                                    tagContextMenu(for: tag)
                                }
                            }
                            
                            // Show "Load More" button if there are more tags
                            if repository.tags.count < repository.totalTagCount {
                                Button {
                                    Task {
                                        await repository.loadMoreTags(currentCount: repository.tags.count)
                                    }
                                } label: {
                                    HStack {
                                        if repository.isLoadingTags {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .frame(width: 20)
                                        } else {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundColor(.secondary)
                                                .frame(width: 20)
                                        }
                                        Text("Load More (\(repository.totalTagCount - repository.tags.count) remaining)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(repository.isLoadingTags)
                                .pointingHandCursor()
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: repository.totalTagCount > 0 ? "TAGS (\(repository.totalTagCount))" : "TAGS",
                        isExpanded: expandedSections.contains("tags"),
                        isLoading: repository.isLoadingTags
                    ) {
                        toggleSection("tags")
                    }
                }
            }
            
            // Stashes section
            if !repository.stashes.isEmpty {
                Section {
                    if expandedSections.contains("stashes") {
                        ForEach(repository.stashes, id: \.self) { stash in
                            SidebarItem(
                                title: stash.message,
                                icon: .system("archivebox"),
                                subtitle: stash.shortName
                            )
                            .tag(SidebarSelection.stash(stash))
                            .contextMenu {
                                stashContextMenu(for: stash)
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "STASHES (\(repository.stashes.count))", isExpanded: expandedSections.contains("stashes")) {
                        toggleSection("stashes")
                    }
                }
            }
            
            // Submodules section
            if !repository.submodules.isEmpty {
                Section {
                    if expandedSections.contains("submodules") {
                        ForEach(repository.submodules, id: \.self) { submodule in
                            SidebarItem(
                                title: submodule.name,
                                icon: .system("folder.badge.gearshape")
                            )
                            .tag(SidebarSelection.submodule(submodule))
                        }
                    }
                } header: {
                    SectionHeader(title: "SUBMODULES (\(repository.submodules.count))", isExpanded: expandedSections.contains("submodules")) {
                        toggleSection("submodules")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: showDiffSheet) { oldValue, newValue in
            if newValue, let compareRef = diffCompareRef {
                openDiffWindow(for: compareRef)
            }
        }
    }
    
    // MARK: - Diff Window
    
    private func openDiffWindow(for compareRef: GitRef) {
        DiffWindowManager.shared.openDiffWindow(
            repository: repository,
            compareRef: compareRef,
            baseRef: repository.defaultBranch
        )
        
        // Reset state
        showDiffSheet = false
        diffCompareRef = nil
        diffContent = ""
    }
    
    // MARK: - Helpers
    
    private var stageBadge: Int? {
        let count = repository.stagedFiles.count + repository.unstagedFiles.count
        return count > 0 ? count : nil
    }
    
    private var isStageSelected: Bool {
        if case .stage = selection { return true }
        return false
    }
    
    private func remoteBranches(for remote: String) -> [GitRef] {
        return repository.remoteBranches.filter { $0.name.hasPrefix("\(remote)/") }
    }
    
    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
    
    // MARK: - Context Menus
    
    @ViewBuilder
    private func branchContextMenu(for branch: GitRef) -> some View {
        Button("Checkout") {
            Task {
                try? await repository.checkout(ref: branch)
            }
        }
        
        Button("Compare with \(repository.defaultBranch)") {
            diffCompareRef = branch
            showDiffSheet = true
        }
        .disabled(branch.name == repository.defaultBranch)
        
        Divider()
        
        Button("Delete Branch", role: .destructive) {
            Task {
                try? await repository.deleteRef(branch)
            }
        }
        .disabled(branch.name == repository.currentBranch?.name)
    }
    
    @ViewBuilder
    private func remoteBranchContextMenu(for branch: GitRef) -> some View {
        Button("Checkout") {
            Task {
                try? await repository.checkout(ref: branch)
            }
        }
        
        Button("Compare with \(repository.defaultBranch)") {
            diffCompareRef = branch
            showDiffSheet = true
        }
        
        Divider()
        
        Button("Fetch") {
            Task {
                try? await repository.fetch(remote: branch.remoteName)
            }
        }
    }
    
    @ViewBuilder
    private func tagContextMenu(for tag: GitRef) -> some View {
        Button("Checkout Tag") {
            Task {
                try? await repository.checkout(ref: tag)
            }
        }
        
        Button("Compare with \(repository.defaultBranch)") {
            diffCompareRef = tag
            showDiffSheet = true
        }
        
        Divider()
        
        Button("Delete Tag", role: .destructive) {
            Task {
                try? await repository.deleteRef(tag)
            }
        }
    }
    
    @ViewBuilder
    private func stashContextMenu(for stash: GitStash) -> some View {
        Button("Apply") {
            Task {
                try? await repository.stashApply(stash: stash)
            }
        }
        
        Button("Pop") {
            Task {
                try? await repository.stashPop(stash: stash)
            }
        }
        
        Divider()
        
        Button("Drop", role: .destructive) {
            Task {
                try? await repository.stashDrop(stash: stash)
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let isExpanded: Bool
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

struct SidebarItem: View {
    let title: String
    let icon: ImageSource
    var badge: Int? = nil
    var isCurrent: Bool = false
    var isSelected: Bool = false
    var subtitle: String? = nil
    
    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .fontWeight(isCurrent ? .semibold : .regular)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
            
            if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }
        }
        .contentShape(Rectangle())
        .pointingHandCursor()
    }
}

// MARK: - Diff Compare Window Content

struct DiffCompareWindowContent: View {
    @ObservedObject var repository: GitRepository
    let compareRef: GitRef
    let baseRef: String
    
    @State private var diffContent: String = ""
    @State private var isLoading: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare: \(baseRef) ↔ \(compareRef.name)")
                        .font(.headline)
                    
                    Text("Showing changes from \(baseRef) to \(compareRef.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        isLoading = true
                        diffContent = await repository.diffBetweenRefs(from: baseRef, to: compareRef.name)
                        isLoading = false
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload diff")
                .pointingHandCursor()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Diff content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading diff...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diffContent.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No differences found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("The branches are identical")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DiffView(content: diffContent, filePath: nil)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadDiff()
        }
    }
    
    private func loadDiff() {
        Task {
            isLoading = true
            diffContent = await repository.diffBetweenRefs(from: baseRef, to: compareRef.name)
            isLoading = false
        }
    }
}

// MARK: - Diff Window Manager

class DiffWindowManager: NSObject, NSWindowDelegate {
    static let shared = DiffWindowManager()
    
    private var windowControllers: [NSWindowController] = []
    
    private override init() {
        super.init()
    }
    
    func openDiffWindow(repository: GitRepository, compareRef: GitRef, baseRef: String) {
        let diffView = DiffCompareWindowContent(
            repository: repository,
            compareRef: compareRef,
            baseRef: baseRef
        )
        
        let hostingController = NSHostingController(rootView: diffView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Compare: \(baseRef) ↔ \(compareRef.name)"
        window.contentViewController = hostingController
        window.delegate = self
        window.center()
        
        let windowController = NSWindowController(window: window)
        windowControllers.append(windowController)
        
        windowController.showWindow(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        
        // Remove the window controller from our list
        windowControllers.removeAll { controller in
            controller.window === closingWindow
        }
    }
}
