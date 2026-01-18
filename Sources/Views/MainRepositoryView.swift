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

struct MainRepositoryView: View {
    @ObservedObject var repository: GitRepository
    @State private var selection: SidebarSelection = .stage
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Toast state
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var isToastError: Bool = false
    
    // Action loading states
    @State private var loadingActions: Set<String> = []
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(repository: repository, selection: $selection)
                .frame(minWidth: 180)
        } detail: {
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
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        Button {
            performAction(name: "Fetch") {
                try await repository.fetch()
            }
        } label: {
            if loadingActions.contains("Fetch") {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label("Fetch", systemImage: "arrow.down")
            }
        }
        .help("Fetch from remote")
        .disabled(loadingActions.contains("Fetch"))
        .pointingHandCursor()
        
        Button {
            performAction(name: "Pull") {
                try await repository.pull()
            }
        } label: {
            if loadingActions.contains("Pull") {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label("Pull", systemImage: "arrow.down.circle")
            }
        }
        .help("Pull from remote")
        .disabled(loadingActions.contains("Pull"))
        .pointingHandCursor()
        
        Button {
            performAction(name: "Push") {
                try await repository.push()
            }
        } label: {
            if loadingActions.contains("Push") {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label("Push", systemImage: "arrow.up.circle")
            }
        }
        .help("Push to remote")
        .disabled(loadingActions.contains("Push"))
        .pointingHandCursor()
        
        Divider()
        
        Button {
            performAction(name: "Refresh") {
                await repository.reloadAll()
                await repository.loadCommits()
            }
        } label: {
            if loadingActions.contains("Refresh") {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .help("Refresh repository")
        .disabled(loadingActions.contains("Refresh"))
        .pointingHandCursor()
    }
    
    private func performAction(name: String, action: @escaping () async throws -> Void) {
        guard !loadingActions.contains(name) else { return }
        
        withAnimation {
            _ = loadingActions.insert(name)
        }
        
        Task {
            do {
                try await action()
                withAnimation {
                    _ = loadingActions.remove(name)
                }
                showToast("\(name) completed successfully")
            } catch {
                withAnimation {
                    _ = loadingActions.remove(name)
                }
                showToast("\(name) failed: \(error.localizedDescription)", isError: true)
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
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            if self.toastMessage == message {
                withAnimation {
                    self.showToast = false
                }
            }
        }
    }
}
