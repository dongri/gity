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
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        Button {
            Task {
                try? await repository.fetch()
            }
        } label: {
            Label("Fetch", systemImage: "arrow.down")
        }
        .help("Fetch from remote")
        
        Button {
            Task {
                try? await repository.pull()
            }
        } label: {
            Label("Pull", systemImage: "arrow.down.circle")
        }
        .help("Pull from remote")
        
        Button {
            Task {
                try? await repository.push()
            }
        } label: {
            Label("Push", systemImage: "arrow.up.circle")
        }
        .help("Push to remote")
        
        Divider()
        
        Button {
            Task {
                await repository.reloadAll()
                await repository.loadCommits()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh repository")
    }
}
