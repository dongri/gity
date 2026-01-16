//
//  RelativeDateFormatter.swift
//  GitY
//
//  Relative date formatting utility
//

import Foundation

class GitYRelativeDateFormatter {
    static let shared = GitYRelativeDateFormatter()
    
    private let formatter: RelativeDateTimeFormatter
    
    private init() {
        formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
    }
    
    func string(from date: Date) -> String {
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func fullString(from date: Date) -> String {
        let fullFormatter = DateFormatter()
        fullFormatter.dateStyle = .full
        fullFormatter.timeStyle = .medium
        return fullFormatter.string(from: date)
    }
}
