//
//  PreferencesView.swift
//  GitY
//
//  Preferences/Settings view
//

import SwiftUI

struct PreferencesView: View {
    @AppStorage("showStageViewOnOpen") private var showStageViewOnOpen = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("defaultBranchFilter") private var defaultBranchFilter = 0
    @AppStorage("diffContextLines") private var diffContextLines = 3
    @AppStorage("useMonospaceFont") private var useMonospaceFont = true
    
    @State private var cliInstallStatus: CLIInstallStatus = .notInstalled
    @State private var isInstallingCLI = false
    @State private var installError: String?
    
    var body: some View {
        TabView {
            // General
            Form {
                Section {
                    Toggle("Show Stage view on repository open", isOn: $showStageViewOnOpen)
                    
                    Picker("Default branch filter", selection: $defaultBranchFilter) {
                        Text("All branches").tag(0)
                        Text("Local branches").tag(1)
                        Text("Current branch").tag(2)
                    }
                    
                    Picker("Auto-refresh interval", selection: $refreshInterval) {
                        Text("Never").tag(0)
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
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
                    
                    Toggle("Use monospace font", isOn: $useMonospaceFont)
                }
            }
            .padding(20)
            .tabItem {
                Label("Diff", systemImage: "doc.text")
            }
            
            // Git
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Git executable")
                            .font(.headline)
                        
                        Text(gitVersion)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(gitPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label("Git", systemImage: "terminal")
            }
            
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
                            
                            if cliInstallStatus == .installed {
                                Button("Uninstall") {
                                    uninstallCLI()
                                }
                                .foregroundColor(.red)
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
        }
        .frame(width: 500, height: 320)
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = CLIInstaller.install()
            
            DispatchQueue.main.async {
                isInstallingCLI = false
                if result.success {
                    cliInstallStatus = .installed
                    installError = nil
                } else {
                    installError = result.error
                }
            }
        }
    }
    
    private func uninstallCLI() {
        isInstallingCLI = true
        installError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = CLIInstaller.uninstall()
            
            DispatchQueue.main.async {
                isInstallingCLI = false
                if result.success {
                    cliInstallStatus = .notInstalled
                    installError = nil
                } else {
                    installError = result.error
                }
            }
        }
    }
    
    // MARK: - Git Info
    
    private var gitVersion: String {
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
    
    private var gitPath: String {
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
        
        # Check if it's a git repository
        if [ ! -d "$REPO_PATH/.git" ]; then
            echo "Warning: $REPO_PATH is not a git repository"
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
            
            // Run with admin privileges using AppleScript
            let appleScript = """
            do shell script "bash \(tempPath)" with administrator privileges
            """
            
            var error: NSDictionary?
            if let script = NSAppleScript(source: appleScript) {
                script.executeAndReturnError(&error)
                if let error = error {
                    return Result(success: false, error: error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error")
                }
            }
            
            // Clean up
            try? FileManager.default.removeItem(atPath: tempPath)
            
            return Result(success: true, error: nil)
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
