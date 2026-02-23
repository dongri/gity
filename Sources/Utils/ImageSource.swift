//
//  ImageId.swift
//  GitY
//
//  Created by Sergey on 22.02.2026.
//

import SwiftUI

enum ImageSource {
    case system(String)
    case local(String)
}

extension Image {
    init(_ source: ImageSource) {
        switch source {
        case .local(let name):
            self.init(name)
        case .system(let name):
            self.init(systemName: name)
        }
    }
}
