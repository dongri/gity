//
//  WelcomeWindowView.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeWindowView: View {    
    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let subtitle1: String
    let subtitle2: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                WelcomeMainView(
                    title: title,
                    subtitle1: subtitle1,
                    subtitle2: subtitle2
                )
                .padding(.top, 20)
                .padding(.horizontal, 56)
                .padding(.bottom, 16)
                .frame(width: 460)
                .frame(maxHeight: .infinity)
                
                RecentView()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if colorScheme == .dark {
                            Color(.black).opacity(0.275)
                                .background(.ultraThickMaterial)
                        } else {
                            Color(.white)
                                .background(.regularMaterial)
                        }
                    }
            }
            
            DismissWindowButton {
                Darwin.exit(0)
            }
        }
    }
}

#Preview {
    WelcomeWindowView(
        title: "GitY",
        subtitle1: "A powerful Git client for macOS",
        subtitle2: "Version 1.0"
    )
    .frame(width: 740, height: 460)
    .environmentObject(AppState())
}
