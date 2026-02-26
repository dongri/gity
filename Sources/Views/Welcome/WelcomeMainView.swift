//
//  WelcomeMainView.swift
//  GitY
//
//  Created by Sergey on 26.02.2026.
//

import SwiftUI

struct WelcomeMainView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    var title: String
    var subtitle: String
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)
            ZStack {
                if colorScheme == .dark {
                    Rectangle()
                        .frame(width: 104, height: 104)
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .blur(radius: 64)
                        .opacity(0.5)
                }
                (Image(nsImage: NSApp.applicationIconImage))
                    .resizable()
                    .frame(width: 128, height: 128)
            }
            
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(subtitle)
                .foregroundColor(.secondary)
                .font(.system(size: 13.5))
            
            Spacer().frame(height: 40)
            
            actionsView
            Spacer()
        }
    }
    
    var actionsView: some View {
        EmptyView()
    }
}
