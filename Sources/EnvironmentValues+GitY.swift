//
//  EnvironmentValues+GitY.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var openRepository: (URL) -> Void = {_ in }
    @Entry var closeRepository: () -> Void = { }
}
