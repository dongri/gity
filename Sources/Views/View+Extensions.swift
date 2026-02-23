import SwiftUI
import AppKit

extension View {
    func pointingHandCursor() -> some View {
        self.background(PointingHandView())
    }
}

struct PointingHandView: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorView {
        let view = CursorView()
        return view
    }

    func updateNSView(_ nsView: CursorView, context: Context) {
        // No update needed
    }
    
    typealias NSViewType = CursorView
}

class CursorView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension View {
    @ViewBuilder
    func `ifLet`<T, Content: View>(option: T?, transform: (Self, T) -> Content) -> some View {
        if let option {
            transform(self, option)
        } else {
            self
        }
    }    
}
