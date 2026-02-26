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

    let title: String
    let subtitle1: String
    let subtitle2: String
    
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
            
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle1)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(subtitle2)
                    .foregroundColor(.secondary)
                    .font(.system(size: 13.5))
            }
            
            Spacer()
            
            actionsView
            Spacer()
        }
    }
    
    var actionsView: some View {
        HStack {
            VStack(spacing: 10) {
                ForEach(actions.indices, id: \.self) {
                    WelcomeActionButton(actions[$0])
                }
            }
        }
    }
    
    private let actions = [
        WelcomeActionData(
            title: "Open repository...",
            image: .system("folder"),
            shortcut: KeyboardShortcut("O", modifiers: .command),
            action: {
                // no op
            }
        ),
        
        WelcomeActionData(
            title: "Clone repository...",
            image: .system("square.and.arrow.down.on.square"),
            shortcut: KeyboardShortcut("C", modifiers: .command),
            action: {
                // no op
            }
        )
    ]
}
