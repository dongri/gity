//
//  Bundle+Utils.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import Foundation

extension Bundle {
    static var appName: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    static var versionString: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
