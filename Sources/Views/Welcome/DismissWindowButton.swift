//
//  DismissWindowButton.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct DismissWindowButton: View {
    @State private var isHoveringCloseButton = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(.system("xmark.circle.fill"))
                .foregroundColor(imageForeground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
        .onHover { hover in
            withAnimation(.linear(duration: 0.15)) {
                isHoveringCloseButton = hover
            }
        }
        .padding(10)
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }
    
    private var imageForeground: Color {
        isHoveringCloseButton ? Color(.secondaryLabelColor) : Color(.tertiaryLabelColor)
    }
}
