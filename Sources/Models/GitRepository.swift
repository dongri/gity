//
//  GitRepository.swift
//  GitY
//
//  Core Git repository model - Swift equivalent of PBGitRepository
//

import Foundation
import Combine

enum BranchFilterType: Int {
    case all = 0
    case localRemote = 1
    case selected = 2
}

class GitRepository: ObservableObject {
    // MARK: - Properties
    let url: URL
    @Published var currentBranch: GitRef?
    @Published var branches: [GitRef] = []
    @Published var remoteBranches: [GitRef] = []
    @Published var remotes: [String] = []
    @Published var tags: [GitRef] = []
    @Published var isLoadingTags: Bool = false
    @Published var totalTagCount: Int = 0
    @Published var stashes: [GitStash] = []
    @Published var submodules: [GitSubmodule] = []
    @Published var commits: [GitCommit] = []
    @Published var currentBranchFilter: BranchFilterType = .all
    @Published var hasChanges: Bool = false
    
    // Loading states for UI feedback
    @Published var isLoadingRefs: Bool = false
    @Published var isLoadingCommits: Bool = false
    @Published var isLoadingIndex: Bool = false
    @Published var isInitializing: Bool = true
    
    // Index
    @Published var stagedFiles: [ChangedFile] = []
    @Published var unstagedFiles: [ChangedFile] = []
    
    private var fileWatcher: DirectoryWatcher?
    private var cancellables = Set<AnyCancellable>()
    
    // Limits for performance
    private let maxVisibleTags: Int = 30
    private let maxVisibleBranches: Int = 100
    private let initialCommitLimit: Int = 200
    
    // MARK: - Computed Properties
    var workingDirectory: URL {
        if url.lastPathComponent == ".git" {
            return url.deletingLastPathComponent()
        }
        return url
    }
    
    var gitDirectory: URL {
        if url.lastPathComponent == ".git" {
            return url
        }
        return url.appendingPathComponent(".git")
    }
    
    var projectName: String {
        return workingDirectory.lastPathComponent
    }
    
    var isBareRepository: Bool {
        let configPath = gitDirectory.appendingPathComponent("config")
        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else {
            return false
        }
        return content.contains("bare = true")
    }
    
    // MARK: - Initialization
    init(url: URL) throws {
        self.url = url
        
        // Verify it's a git repository
        let gitDir = url.lastPathComponent == ".git" ? url : url.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            throw GitError.notARepository
        }
        
        // Initial load - done in background, UI shows loading state
        Task { @MainActor in
            await self.initializeRepositoryAsync()
        }
    }
    
    // MARK: - Async Initialization
    @MainActor
    private func initializeRepositoryAsync() async {
        isInitializing = true
        
        // Load essential data first (current branch only) for quick UI response
        await loadCurrentBranchAsync()
        
        // Then load other data in parallel, but don't block
        async let refsTask: () = loadRefsInBackground()
        async let indexTask: () = reloadIndexAsync()
        
        // Wait for essential tasks
        await refsTask
        await indexTask
        
        isInitializing = false
        
        // Load commits after UI is responsive
        await loadCommitsAsync(limit: initialCommitLimit)
        
        // Load secondary data in background (stashes, submodules)
        Task {
            await reloadStashesAsync()
            await reloadSubmodulesAsync()
        }
    }
    
    // MARK: - Repository Loading (All Async)
    @MainActor
    func reloadAll() async {
        isLoadingRefs = true
        
        // Run all loads in parallel
        async let refsTask: () = loadRefsInBackground()
        async let indexTask: () = reloadIndexAsync()
        async let stashesTask: () = reloadStashesAsync()
        async let submodulesTask: () = reloadSubmodulesAsync()
        
        await refsTask
        await indexTask
        await stashesTask
        await submodulesTask
        
        isLoadingRefs = false
    }
    
    @MainActor
    private func loadCurrentBranchAsync() async {
        let head = await runGitAsync(["symbolic-ref", "--short", "HEAD"])
        let trimmedHead = head.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHead.isEmpty && !trimmedHead.contains("fatal") {
            currentBranch = GitRef(name: trimmedHead, type: .branch)
        }
    }
    
    @MainActor
    private func loadRefsInBackground() async {
        isLoadingRefs = true
        defer { isLoadingRefs = false }
        
        // Load branches, remotes, and tags in parallel
        async let branchesTask = loadBranchesAsync()
        async let remoteBranchesTask = loadRemoteBranchesAsync()
        async let remotesTask = loadRemotesAsync()
        async let tagsTask = loadTagsAsync()
        
        let (loadedBranches, loadedRemoteBranches, loadedRemotes, loadedTags) = await (branchesTask, remoteBranchesTask, remotesTask, tagsTask)
        
        branches = loadedBranches
        remoteBranches = loadedRemoteBranches
        remotes = loadedRemotes
        tags = loadedTags.tags
        totalTagCount = loadedTags.total
    }
    
    private func loadBranchesAsync() async -> [GitRef] {
        let output = await runGitAsync(["branch", "--format=%(refname:short)"])
        return output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .prefix(maxVisibleBranches)
            .map { GitRef(name: $0, type: .branch) }
    }
    
    private func loadRemoteBranchesAsync() async -> [GitRef] {
        let output = await runGitAsync(["branch", "-r", "--format=%(refname:short)"])
        return output.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.contains("HEAD") }
            .prefix(maxVisibleBranches)
            .map { GitRef(name: $0, type: .remoteBranch) }
    }
    
    private func loadRemotesAsync() async -> [String] {
        let output = await runGitAsync(["remote"])
        return output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
    }
    
    private func loadTagsAsync() async -> (tags: [GitRef], total: Int) {
        // Get count first
        let countOutput = await runGitAsync(["tag", "-l", "--sort=-version:refname"])
        let allTagNames = countOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
        let total = allTagNames.count
        
        // Return limited tags
        let limitedTags = allTagNames.prefix(maxVisibleTags).map { GitRef(name: $0, type: .tag) }
        return (tags: limitedTags, total: total)
    }
    
    @MainActor
    func reloadTagsAsync() async {
        guard !isLoadingTags else { return }
        isLoadingTags = true
        defer { isLoadingTags = false }
        
        let result = await loadTagsAsync()
        tags = result.tags
        totalTagCount = result.total
    }
    
    @MainActor
    func loadMoreTags(currentCount: Int, batchSize: Int = 30) async {
        guard !isLoadingTags else { return }
        guard currentCount < totalTagCount else { return }
        
        isLoadingTags = true
        defer { isLoadingTags = false }
        
        let tagOutput = await runGitAsync(["tag", "-l", "--sort=-version:refname"])
        let allTagNames = tagOutput.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        
        let endIndex = min(currentCount + batchSize, allTagNames.count)
        tags = Array(allTagNames.prefix(endIndex)).map { GitRef(name: $0, type: .tag) }
    }
    
    @MainActor
    func reloadStashesAsync() async {
        let output = await runGitAsync(["stash", "list", "--format=%H|%s"])
        stashes = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .enumerated()
            .compactMap { index, line in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 2 else { return nil }
                return GitStash(index: index, sha: parts[0], message: parts[1])
            }
    }
    
    @MainActor
    func reloadSubmodulesAsync() async {
        let output = await runGitAsync(["submodule", "status"])
        submodules = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.components(separatedBy: " ")
                guard parts.count >= 2 else { return nil }
                let sha = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
                return GitSubmodule(path: parts[1], sha: sha)
            }
    }
    
    @MainActor
    func reloadIndexAsync() async {
        isLoadingIndex = true
        defer { isLoadingIndex = false }
        
        // Run all index operations in parallel
        async let stagedTask = runGitAsync(["diff", "--cached", "--name-status"])
        async let unstagedTask = runGitAsync(["diff", "--name-status"])
        async let untrackedTask = runGitAsync(["ls-files", "--others", "--exclude-standard"])
        
        let (stagedOutput, unstagedOutput, untrackedOutput) = await (stagedTask, unstagedTask, untrackedTask)
        
        stagedFiles = parseChangedFiles(stagedOutput, staged: true)
        
        let modifiedFiles = parseChangedFiles(unstagedOutput, staged: false)
        let untrackedFiles = untrackedOutput.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { ChangedFile(path: $0, status: .untracked, staged: false) }
        
        unstagedFiles = modifiedFiles + untrackedFiles
        hasChanges = !stagedFiles.isEmpty || !unstagedFiles.isEmpty
    }
    
    // Legacy sync methods - now just call async versions
    @MainActor
    func reloadRefs() async {
        await loadRefsInBackground()
    }
    
    @MainActor
    func reloadStashes() async {
        await reloadStashesAsync()
    }
    
    @MainActor
    func reloadSubmodules() async {
        await reloadSubmodulesAsync()
    }
    
    @MainActor
    func reloadIndex() async {
        await reloadIndexAsync()
    }
    
    private func parseChangedFiles(_ output: String, staged: Bool) -> [ChangedFile] {
        return output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 2 else { return nil }
                let status = FileStatus.from(gitStatus: parts[0])
                return ChangedFile(path: parts[1], status: status, staged: staged)
            }
    }
    
    // MARK: - Commit Loading (Async)
    @MainActor
    func loadCommits(limit: Int = 200) async {
        await loadCommitsAsync(limit: limit)
    }
    
    @MainActor
    func loadCommitsAsync(limit: Int = 200) async {
        isLoadingCommits = true
        defer { isLoadingCommits = false }
        
        let format = "%H|%h|%s|%an|%ae|%aI|%P|%D"
        let args: [String]
        
        switch currentBranchFilter {
        case .all:
            args = ["log", "--all", "-\(limit)", "--format=\(format)"]
        case .localRemote:
            args = ["log", "-\(limit)", "--format=\(format)"]
        case .selected:
            if let branch = currentBranch {
                args = ["log", branch.name, "-\(limit)", "--format=\(format)"]
            } else {
                args = ["log", "-\(limit)", "--format=\(format)"]
            }
        }
        
        let output = await runGitAsync(args)
        commits = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { GitCommit.from(logLine: $0) }
    }
    
    @MainActor
    func loadMoreCommits(currentCount: Int, batchSize: Int = 200) async {
        guard !isLoadingCommits else { return }
        isLoadingCommits = true
        defer { isLoadingCommits = false }
        
        let newLimit = currentCount + batchSize
        let format = "%H|%h|%s|%an|%ae|%aI|%P|%D"
        let args: [String]
        
        switch currentBranchFilter {
        case .all:
            args = ["log", "--all", "-\(newLimit)", "--format=\(format)"]
        case .localRemote:
            args = ["log", "-\(newLimit)", "--format=\(format)"]
        case .selected:
            if let branch = currentBranch {
                args = ["log", branch.name, "-\(newLimit)", "--format=\(format)"]
            } else {
                args = ["log", "-\(newLimit)", "--format=\(format)"]
            }
        }
        
        let output = await runGitAsync(args)
        commits = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { GitCommit.from(logLine: $0) }
    }
    
    // MARK: - Git Operations (All Async)
    func stage(files: [ChangedFile]) async throws {
        let paths = files.map { $0.path }
        _ = await runGitAsync(["add", "--"] + paths)
        await MainActor.run {
            Task {
                await self.reloadIndexAsync()
            }
        }
    }
    
    func unstage(files: [ChangedFile]) async throws {
        let paths = files.map { $0.path }
        _ = await runGitAsync(["reset", "HEAD", "--"] + paths)
        await MainActor.run {
            Task {
                await self.reloadIndexAsync()
            }
        }
    }
    
    func discard(files: [ChangedFile]) async throws {
        let paths = files.filter { $0.status != .untracked }.map { $0.path }
        if !paths.isEmpty {
            _ = await runGitAsync(["checkout", "--"] + paths)
        }
        
        // For untracked files, delete them
        for file in files where file.status == .untracked {
            try? FileManager.default.removeItem(at: workingDirectory.appendingPathComponent(file.path))
        }
        
        await MainActor.run {
            Task {
                await self.reloadIndexAsync()
            }
        }
    }
    
    func commit(message: String, amend: Bool = false) async throws {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }
        let output = await runGitAsync(args)
        if output.contains("error") || output.contains("fatal") {
            throw GitError.commitFailed(output)
        }
        await MainActor.run {
            Task {
                await self.reloadIndexAsync()
                await self.loadCommitsAsync()
            }
        }
    }
    
    func checkout(ref: GitRef) async throws {
        let output = await runGitAsync(["checkout", ref.name])
        if output.contains("error") || output.contains("fatal") {
            throw GitError.checkoutFailed(output)
        }
        await MainActor.run {
            Task {
                await self.loadRefsInBackground()
                await self.loadCommitsAsync()
            }
        }
    }
    
    func createBranch(name: String, at ref: String? = nil) async throws {
        var args = ["branch", name]
        if let ref = ref {
            args.append(ref)
        }
        let output = await runGitAsync(args)
        if output.contains("error") || output.contains("fatal") {
            throw GitError.branchCreationFailed(output)
        }
        await MainActor.run {
            Task {
                await self.loadRefsInBackground()
            }
        }
    }
    
    func createTag(name: String, message: String? = nil, at ref: String? = nil) async throws {
        var args = ["tag"]
        if let message = message {
            args += ["-a", name, "-m", message]
        } else {
            args.append(name)
        }
        if let ref = ref {
            args.append(ref)
        }
        let output = await runGitAsync(args)
        if output.contains("error") || output.contains("fatal") {
            throw GitError.tagCreationFailed(output)
        }
        await MainActor.run {
            Task {
                await self.loadRefsInBackground()
            }
        }
    }
    
    func deleteRef(_ ref: GitRef) async throws {
        let args: [String]
        switch ref.type {
        case .branch:
            args = ["branch", "-d", ref.name]
        case .remoteBranch:
            let parts = ref.name.components(separatedBy: "/")
            if parts.count >= 2 {
                args = ["push", parts[0], "--delete", parts.dropFirst().joined(separator: "/")]
            } else {
                throw GitError.invalidRef
            }
        case .tag:
            args = ["tag", "-d", ref.name]
        default:
            throw GitError.invalidRef
        }
        
        let output = await runGitAsync(args)
        if output.contains("error") || output.contains("fatal") {
            throw GitError.deleteFailed(output)
        }
        await MainActor.run {
            Task {
                await self.loadRefsInBackground()
            }
        }
    }
    
    func fetch(remote: String? = nil) async throws {
        var args = ["fetch"]
        if let remote = remote {
            args.append(remote)
        } else {
            args.append("--all")
        }
        let output = await runGitAsync(args)
        if output.contains("fatal") {
            throw GitError.fetchFailed(output)
        }
        await MainActor.run {
            Task {
                await self.loadRefsInBackground()
                await self.loadCommitsAsync()
            }
        }
    }
    
    func pull(remote: String? = nil, rebase: Bool = false) async throws {
        var args = ["pull"]
        if rebase {
            args.append("--rebase")
        }
        if let remote = remote {
            args.append(remote)
        }
        let output = await runGitAsync(args)
        if output.contains("fatal") || output.contains("CONFLICT") {
            throw GitError.pullFailed(output)
        }
        await MainActor.run {
            Task {
                await self.reloadAll()
                await self.loadCommitsAsync()
            }
        }
    }
    
    func push(remote: String? = nil, branch: String? = nil) async throws {
        var args = ["push"]
        if let remote = remote {
            args.append(remote)
        }
        if let branch = branch {
            args.append(branch)
        }
        let output = await runGitAsync(args)
        if output.contains("fatal") || output.contains("rejected") {
            throw GitError.pushFailed(output)
        }
    }
    
    func stashSave(message: String? = nil, keepIndex: Bool = false) async throws {
        var args = ["stash", "push"]
        if keepIndex {
            args.append("--keep-index")
        }
        if let message = message {
            args += ["-m", message]
        }
        _ = await runGitAsync(args)
        await MainActor.run {
            Task {
                await self.reloadStashesAsync()
                await self.reloadIndexAsync()
            }
        }
    }
    
    func stashPop(stash: GitStash? = nil) async throws {
        var args = ["stash", "pop"]
        if let stash = stash {
            args.append("stash@{\(stash.index)}")
        }
        let output = await runGitAsync(args)
        if output.contains("CONFLICT") {
            throw GitError.stashConflict(output)
        }
        await MainActor.run {
            Task {
                await self.reloadStashesAsync()
                await self.reloadIndexAsync()
            }
        }
    }
    
    func stashApply(stash: GitStash? = nil) async throws {
        var args = ["stash", "apply"]
        if let stash = stash {
            args.append("stash@{\(stash.index)}")
        }
        let output = await runGitAsync(args)
        if output.contains("CONFLICT") {
            throw GitError.stashConflict(output)
        }
        await MainActor.run {
            Task {
                await self.reloadIndexAsync()
            }
        }
    }
    
    func stashDrop(stash: GitStash) async throws {
        _ = await runGitAsync(["stash", "drop", "stash@{\(stash.index)}"])
        await MainActor.run {
            Task {
                await self.reloadStashesAsync()
            }
        }
    }
    
    // MARK: - Diff (Async for performance)
    func diffAsync(for commit: GitCommit) async -> String {
        return await runGitAsync(["show", commit.sha, "--format=", "--stat-width=200", "-p"])
    }
    
    func diffAsync(for file: ChangedFile) async -> String {
        if file.staged {
            return await runGitAsync(["diff", "--cached", "--", file.path])
        } else if file.status == .untracked {
            // For untracked files, show the file content
            let filePath = workingDirectory.appendingPathComponent(file.path)
            return (try? String(contentsOf: filePath, encoding: .utf8)) ?? ""
        } else {
            return await runGitAsync(["diff", "--", file.path])
        }
    }
    
    // Synchronous versions (kept for backward compatibility)
    func diff(for commit: GitCommit) -> String {
        return runGit(["show", commit.sha, "--format="])
    }
    
    func diff(for file: ChangedFile) -> String {
        if file.staged {
            return runGit(["diff", "--cached", "--", file.path])
        } else if file.status == .untracked {
            let filePath = workingDirectory.appendingPathComponent(file.path)
            return (try? String(contentsOf: filePath, encoding: .utf8)) ?? ""
        } else {
            return runGit(["diff", "--", file.path])
        }
    }
    
    // MARK: - Git Command Execution
    
    /// Async git command execution - runs on background thread
    func runGitAsync(_ arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: "")
                    return
                }
                let result = self.runGitSync(arguments)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Synchronous git execution - only use from background threads
    private func runGitSync(_ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            return output + errorOutput
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    @discardableResult
    func runGit(_ arguments: [String]) -> String {
        return runGitSync(arguments)
    }
}

// MARK: - Git Errors
enum GitError: LocalizedError {
    case notARepository
    case commitFailed(String)
    case checkoutFailed(String)
    case branchCreationFailed(String)
    case tagCreationFailed(String)
    case invalidRef
    case deleteFailed(String)
    case fetchFailed(String)
    case pullFailed(String)
    case pushFailed(String)
    case stashConflict(String)
    
    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "Not a valid Git repository"
        case .commitFailed(let msg):
            return "Commit failed: \(msg)"
        case .checkoutFailed(let msg):
            return "Checkout failed: \(msg)"
        case .branchCreationFailed(let msg):
            return "Branch creation failed: \(msg)"
        case .tagCreationFailed(let msg):
            return "Tag creation failed: \(msg)"
        case .invalidRef:
            return "Invalid reference"
        case .deleteFailed(let msg):
            return "Delete failed: \(msg)"
        case .fetchFailed(let msg):
            return "Fetch failed: \(msg)"
        case .pullFailed(let msg):
            return "Pull failed: \(msg)"
        case .pushFailed(let msg):
            return "Push failed: \(msg)"
        case .stashConflict(let msg):
            return "Stash conflict: \(msg)"
        }
    }
}
