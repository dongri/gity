//
//  PreferencesView.swift
//  GitY
//
//  Preferences/Settings view
//

import SwiftUI
import Foundation

extension Notification.Name {
    static let openAISettings = Notification.Name("openAISettings")
}

struct PreferencesView: View {
    @AppStorage("showStageViewOnOpen") private var showStageViewOnOpen = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("defaultBranchFilter") private var defaultBranchFilter = 0
    @AppStorage("diffContextLines") private var diffContextLines = 3
    @AppStorage("useMonospaceFont") private var useMonospaceFont = true
    
    @State private var selectedTab = 0
    @State private var cliInstallStatus: CLIInstallStatus = .notInstalled
    @State private var isInstallingCLI = false
    @State private var installError: String?
    
    // Git info - loaded once on appear to avoid blocking UI
    @State private var gitVersionText: String = "Loading..."
    @State private var gitPathText: String = "Loading..."
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // General
            Form {
                Section {
                    Toggle("Show Stage view on repository open", isOn: $showStageViewOnOpen)
                        .pointingHandCursor()
                    
                    Picker("Default branch filter", selection: $defaultBranchFilter) {
                        Text("All branches").tag(0)
                        Text("Local branches").tag(1)
                        Text("Current branch").tag(2)
                    }
                    .pointingHandCursor()
                    
                    Picker("Auto-refresh interval", selection: $refreshInterval) {
                        Text("Never").tag(0)
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                    }
                    .pointingHandCursor()
                }
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)
            
            // Diff
            Form {
                Section {
                    Picker("Context lines", selection: $diffContextLines) {
                        Text("1 line").tag(1)
                        Text("2 lines").tag(2)
                        Text("3 lines").tag(3)
                        Text("5 lines").tag(5)
                        Text("10 lines").tag(10)
                    }
                    .pointingHandCursor()
                    
                    Toggle("Use monospace font", isOn: $useMonospaceFont)
                        .pointingHandCursor()
                }
            }
            .padding(20)
            .tabItem {
                Label("Diff", systemImage: "doc.text")
            }
            .tag(1)
            
            // Git
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Git executable")
                            .font(.headline)
                        
                        Text(gitVersionText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(gitPathText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Git", systemImage: "terminal")
            }
            .onAppear {
                loadGitInfo()
            }
            .tag(2)
            
            // Integration
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Command Line Tools")
                            .font(.headline)
                        
                        Text("Install the 'gity' command to open repositories from Terminal.")
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Installation path:")
                                .foregroundColor(.secondary)
                            Text("/usr/local/bin/gity")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack(spacing: 12) {
                            switch cliInstallStatus {
                            case .notInstalled:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Not installed")
                                    .foregroundColor(.secondary)
                            case .installed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Installed")
                                    .foregroundColor(.secondary)
                            case .outdated:
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Outdated")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let error = installError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            Button(action: installCLI) {
                                HStack {
                                    if isInstallingCLI {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                    Text(cliInstallStatus == .installed ? "Reinstall Command Line Tools" : "Install Command Line Tools")
                                }
                            }
                            .disabled(isInstallingCLI)
                            .pointingHandCursor()
                            
                            if cliInstallStatus == .installed {
                                Button("Uninstall") {
                                    uninstallCLI()
                                }
                                .foregroundColor(.red)
                                .pointingHandCursor()
                            }
                        }
                        
                        Divider()
                        
                        Text("Usage:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("gity .")
                                .font(.system(.body, design: .monospaced))
                            Text("Open current directory in GitY")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("gity /path/to/repo")
                                .font(.system(.body, design: .monospaced))
                            Text("Open specific repository in GitY")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Integration", systemImage: "terminal.fill")
            }
            .onAppear {
                checkCLIInstallStatus()
            }
            .tag(3)
            
            // AI
            AIPreferencesView()
                .padding(20)
                .tabItem {
                    Label("AI", systemImage: "brain")
                }
                .tag(4)
        }
        .frame(width: 500, height: 320)
        .onAppear {
            if UserDefaults.standard.bool(forKey: "OpenAISettingsOnLoad") {
                selectedTab = 4
                UserDefaults.standard.set(false, forKey: "OpenAISettingsOnLoad")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAISettings)) { _ in
            selectedTab = 4
        }
    }
    
    // MARK: - CLI Installation
    
    enum CLIInstallStatus {
        case notInstalled
        case installed
        case outdated
    }
    
    private func checkCLIInstallStatus() {
        let cliPath = "/usr/local/bin/gity"
        if FileManager.default.fileExists(atPath: cliPath) {
            cliInstallStatus = .installed
        } else {
            cliInstallStatus = .notInstalled
        }
    }
    
    private func installCLI() {
        isInstallingCLI = true
        installError = nil
        
        // Use asyncAfter to allow SwiftUI to update the view first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Run installer on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let result = CLIInstaller.install()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isInstallingCLI = false
                    if result.success {
                        self.cliInstallStatus = .installed
                        self.installError = nil
                    } else {
                        self.installError = result.error
                    }
                }
            }
        }
    }
    
    private func uninstallCLI() {
        isInstallingCLI = true
        installError = nil
        
        // Use asyncAfter to allow SwiftUI to update the view first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Run uninstaller on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let result = CLIInstaller.uninstall()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isInstallingCLI = false
                    if result.success {
                        self.cliInstallStatus = .notInstalled
                        self.installError = nil
                    } else {
                        self.installError = result.error
                    }
                }
            }
        }
    }
    
    // MARK: - Git Info
    
    private func loadGitInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let version = Self.fetchGitVersion()
            let path = Self.fetchGitPath()
            
            DispatchQueue.main.async {
                self.gitVersionText = version
                self.gitPathText = path
            }
        }
    }
    
    private static func fetchGitVersion() -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["--version"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private static func fetchGitPath() -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["git"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/bin/git"
        } catch {
            return "/usr/bin/git"
        }
    }
}

// MARK: - AI Preferences View

struct AIPreferencesView: View {
    @ObservedObject var llmService = LocalLLMService.shared
    
    var body: some View {
        Form {
            Section(header: Text("Models")) {
                List(llmService.models) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .font(.headline)
                            Text(model.sizeDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if llmService.isModelDownloaded(id: model.id) {
                            if llmService.selectedModelId == model.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Button(action: {
                                    llmService.deleteModel(id: model.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                            } else {
                                Button("Select") {
                                    llmService.selectedModelId = model.id
                                }
                                .pointingHandCursor()
                                
                                Button(action: {
                                    llmService.deleteModel(id: model.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                            }
                        } else {
                            if llmService.isDownloading && llmService.downloadingModelId == model.id {
                                HStack {
                                    ProgressView(value: llmService.downloadProgress)
                                        .progressViewStyle(.linear)
                                        .frame(width: 60)
                                    Text("\(Int(llmService.downloadProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 35, alignment: .trailing)
                                }
                            } else {
                                Button("Download") {
                                    llmService.downloadModel(id: model.id)
                                }
                                .pointingHandCursor()
                                // Disable download button if another model is downloading
                                .disabled(llmService.isDownloading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200)
            }
            
            if let error = llmService.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - CLI Installer

struct CLIInstaller {
    struct Result {
        let success: Bool
        let error: String?
    }
    
    static func install() -> Result {
        // Get the app bundle path
        guard let appPath = Bundle.main.bundlePath as String? else {
            return Result(success: false, error: "Could not find app bundle path")
        }
        
        // Create the shell script content
        let scriptContent = """
        #!/bin/bash
        # GitY Command Line Tool
        # Opens a repository in GitY
        
        APP_PATH="\(appPath)"
        
        if [ $# -eq 0 ]; then
            # No arguments, open current directory
            REPO_PATH="$(pwd)"
        else
            # Use provided path
            REPO_PATH="$1"
            # Convert to absolute path if relative
            if [[ ! "$REPO_PATH" = /* ]]; then
                REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)"
            fi
        fi
        
        if [ -z "$REPO_PATH" ] || [ ! -d "$REPO_PATH" ]; then
            echo "Error: Invalid directory path"
            exit 1
        fi
        
        # Traverse up to find .git directory
        SEARCH_PATH="$REPO_PATH"
        while [ "$SEARCH_PATH" != "/" ]; do
            if [ -d "$SEARCH_PATH/.git" ]; then
                REPO_PATH="$SEARCH_PATH"
                break
            fi
            SEARCH_PATH="$(dirname "$SEARCH_PATH")"
        done
        
        if [ ! -d "$REPO_PATH/.git" ]; then
            echo "Error: Not a git repository (or any parent up to /)"
            exit 1
        fi
        
        # Open GitY with the repository path
        open -a "$APP_PATH" "$REPO_PATH"
        """
        
        // Create temp file
        let tempPath = "/tmp/gity_install_script"
        let installScript = """
        #!/bin/bash
        # Create /usr/local/bin if it doesn't exist
        mkdir -p /usr/local/bin
        
        # Write the gity script
        cat > /usr/local/bin/gity << 'SCRIPT_EOF'
        \(scriptContent)
        SCRIPT_EOF
        
        # Make it executable
        chmod +x /usr/local/bin/gity
        
        echo "GitY CLI installed successfully!"
        """
        
        do {
            try installScript.write(toFile: tempPath, atomically: true, encoding: .utf8)
            
            // Run with admin privileges using osascript (Process is safe on background threads)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"bash \(tempPath)\" with administrator privileges"]
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempPath)
            
            if process.terminationStatus == 0 {
                return Result(success: true, error: nil)
            } else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Installation failed"
                return Result(success: false, error: errorMsg.isEmpty ? "User cancelled" : errorMsg)
            }
        } catch {
            return Result(success: false, error: error.localizedDescription)
        }
    }
    
    static func uninstall() -> Result {
        let appleScript = """
        do shell script "rm -f /usr/local/bin/gity" with administrator privileges
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: appleScript) {
            script.executeAndReturnError(&error)
            if let error = error {
                return Result(success: false, error: error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error")
            }
        }
        
        return Result(success: true, error: nil)
    }
}
