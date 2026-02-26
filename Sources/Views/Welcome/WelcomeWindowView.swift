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

    var title: String
    var subtitle: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                WelcomeMainView(
                    title: title,
                    subtitle: subtitle
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
        subtitle: "Version 1.0"
    )
    .frame(width: 740, height: 460)
    .environmentObject(AppState())
}
