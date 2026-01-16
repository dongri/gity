//
//  DiffView.swift
//  GitY
//
//  Diff view for displaying git diffs with syntax highlighting
//

import SwiftUI
import AppKit

struct DiffView: View {
    let content: String
    let filePath: String?
    
    var body: some View {
        if content.isEmpty {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let filePath = filePath {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(filePath)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                    }
                    
                    DiffContentView(content: content)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DiffContentView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let lines = content.components(separatedBy: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                DiffLine(lineNumber: index + 1, content: line)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DiffLine: View {
    let lineNumber: Int
    let content: String
    
    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
                .background(lineNumberBackground)
            
            // Content
            Text(content)
                .foregroundColor(lineColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
                .background(lineBackground)
        }
    }
    
    private var lineType: DiffLineType {
        if content.hasPrefix("+++") || content.hasPrefix("---") {
            return .header
        } else if content.hasPrefix("@@") {
            return .chunk
        } else if content.hasPrefix("+") && !content.hasPrefix("+++") {
            return .addition
        } else if content.hasPrefix("-") && !content.hasPrefix("---") {
            return .deletion
        }
        return .context
    }
    
    private var lineBackground: Color {
        switch lineType {
        case .addition:
            return Color.green.opacity(0.15)
        case .deletion:
            return Color.red.opacity(0.15)
        case .chunk:
            return Color.blue.opacity(0.1)
        case .header:
            return Color.orange.opacity(0.1)
        case .context:
            return Color.clear
        }
    }
    
    private var lineNumberBackground: Color {
        switch lineType {
        case .addition:
            return Color.green.opacity(0.2)
        case .deletion:
            return Color.red.opacity(0.2)
        default:
            return Color(nsColor: .controlBackgroundColor)
        }
    }
    
    private var lineColor: Color {
        switch lineType {
        case .addition:
            return Color.green
        case .deletion:
            return Color.red
        case .chunk:
            return Color.blue
        case .header:
            return Color.orange
        case .context:
            return Color.primary
        }
    }
}

enum DiffLineType {
    case addition
    case deletion
    case context
    case chunk
    case header
}
