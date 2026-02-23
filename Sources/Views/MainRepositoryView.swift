//
//  MainRepositoryView.swift
//  GitY
//
//  Main repository view with sidebar and content
//

import SwiftUI

enum SidebarSelection: Hashable {
    case stage
    case history
    case branch(GitRef)
    case remote(String)
    case remoteBranch(GitRef)
    case tag(GitRef)
    case stash(GitStash)
    case submodule(GitSubmodule)
}

private enum Action: Hashable {
    case push
    case pull
    case fetch
    case refresh
}

struct MainRepositoryView: View {
    @EnvironmentObject var appState: AppState
    
    @ObservedObject var repository: GitRepository
    @State private var selection: SidebarSelection = .stage
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Toast state
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var isToastError: Bool = false
    
    // Action loading states
    @State private var loadingActions: Set<Action> = []
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(repository: repository, selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 350)
        } detail: {
            Group {
                switch selection {
                case .stage:
                    StageView(repository: repository)
                case .history, .branch, .remoteBranch, .tag:
                    HistoryView(repository: repository, selection: selection)
                case .stash(let stash):
                    StashDetailView(repository: repository, stash: stash)
                case .submodule(let submodule):
                    SubmoduleDetailView(repository: repository, submodule: submodule)
                case .remote:
                    HistoryView(repository: repository, selection: selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(repository.projectName)
        .navigationSubtitle(repository.currentBranch?.name ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarContent
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: isToastError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(isToastError ? .red : .green)
                    Text(toastMessage)
                        .foregroundColor(.primary)
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(20)
                .shadow(radius: 4)
                .padding(.top, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toastMessage) // Force recreate on message change
                .zIndex(100)
            }
        }
        .task {
            appState.addRecentRepository(repository.url)
        }
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        toolbarButton(action: .fetch, title: "Fetch", systemImage: "arrow.down", help: "Fetch from remote") {
            try await repository.fetch()
        }
        
        toolbarButton(action: .pull, title: "Pull", systemImage: "arrow.down.circle", help: "Pull from remote") {
            try await repository.pull()
        }
                
        toolbarButton(action: .push, title: "Push", systemImage: "arrow.up.circle", help: "Push to remote") {
            try await repository.push()
        }
        
        Divider()
        
        toolbarButton(action: .refresh, title: "Refresh", systemImage: "arrow.clockwise", help: "Refresh repository") {
            performRefresh()
        }
        .keyboardShortcut("r", modifiers: .command)
    }
    
    private func toolbarButton(
        action: Action,
        title: String,
        systemImage: String,
        help: String,
        perform: @escaping () async throws -> Void
    ) -> some View {
        Button {
            performAction(action: action, block: perform)
        } label: {
            if loadingActions.contains(action) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .help(help)
        .disabled(loadingActions.contains(action))
        .pointingHandCursor()
    }
    
    private func performAction(action: Action, block: @escaping () async throws -> Void) {
        guard !loadingActions.contains(action) else { return }
        
        withAnimation {
            _ = loadingActions.insert(action)
        }
        
        Task {
            do {
                try await block()
                withAnimation {
                    _ = loadingActions.remove(action)
                }
                showToast("\(action) completed successfully")
            } catch {
                withAnimation {
                    _ = loadingActions.remove(action)
                }
                showToast("\(action) failed: \(error.localizedDescription)", isError: true)
            }
        }
    }
    
    private func performRefresh() {
        guard !loadingActions.contains(.refresh) else { return }
        
        withAnimation {
            _ = loadingActions.insert(.refresh)
        }
        
        Task {
            await repository.reloadAll()
            
            // Load commits based on current sidebar selection
            switch selection {
            case .stage:
                // Stage view - reload index only, no commits needed
                await repository.reloadIndex()
            case .history:
                // History view without specific branch - load all commits
                await repository.loadCommitsForRef(nil, filter: .all)
            case .branch(let ref):
                // Specific local branch selected
                await repository.loadCommitsForRef(ref, filter: .selected)
            case .remoteBranch(let ref):
                // Specific remote branch selected
                await repository.loadCommitsForRef(ref, filter: .selected)
            case .tag(let ref):
                // Specific tag selected
                await repository.loadCommitsForRef(ref, filter: .selected)
            case .remote, .stash, .submodule:
                // Other views - load all commits
                await repository.loadCommitsForRef(nil, filter: .all)
            }
            
            withAnimation {
                _ = loadingActions.remove(.refresh)
            }
            
            // Show appropriate toast message based on selection
            switch selection {
            case .stage:
                showToast("Index refreshed")
            default:
                let commitCount = repository.commits.count
                showToast("\(commitCount) commits loaded")
            }
        }
    }
    
    private func showToast(_ message: String, isError: Bool = false) {
        withAnimation {
            self.toastMessage = message
            self.isToastError = isError
            self.showToast = true
        }
        
        // Auto hide after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            if self.toastMessage == message {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }
}
