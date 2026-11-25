import SwiftUI
import UIKit

private struct HeldInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets? = nil
}

extension EnvironmentValues {
    /// Set only while the open book is being held in place against a screen
    /// rotation. Holds the safe-area insets as the book sees them; views that
    /// care about the fold use these instead of the system's.
    var heldInsets: EdgeInsets? {
        get { self[HeldInsetsKey.self] }
        set { self[HeldInsetsKey.self] = newValue }
    }
}

/// Decides whether the book is open, and keeps the open spread fixed to the
/// device: fold as the spine, a page either side.
///
/// The Duo's inner screen rotates the app even when it only supports
/// portrait. When that leaves the open window taller than wide, this turns
/// the content a quarter turn back so the spread stays where it was.
struct FoldAwareContainer<Content: View>: View {
    /// True where the keyboard must not move the layout.
    let ignoresKeyboard: Bool
    @ViewBuilder let content: (_ isOpen: Bool) -> Content

    /// The interface orientation last seen with the open window wide.
    @State private var wideOrientation: UIInterfaceOrientation = .portrait

    var body: some View {
        GeometryReader { geo in
            let window = BookLayout.windowSize(geo)
            let isOpen = BookLayout.isOpen(window)
            let turned = isOpen && window.height > window.width
            let angle = turned ? counterRotation() : 0

            content(isOpen)
                .environment(\.heldInsets, turned ? Self.mapped(geo.safeAreaInsets, angle: angle) : nil)
                .frame(width: turned ? window.height : nil, height: turned ? window.width : nil)
                .rotationEffect(.degrees(angle))
                .frame(width: turned ? window.width : nil, height: turned ? window.height : nil)
                .ignoresSafeArea(.container, edges: turned ? .all : [])
                .onAppear {
                    remember(window)
                }
                .onChange(of: window) { _, newWindow in
                    remember(newWindow)
                }
        }
        .ignoresSafeArea(.keyboard, edges: ignoresKeyboard ? .all : [])
    }

    private func remember(_ window: CGSize) {
        guard BookLayout.isOpen(window), window.width >= window.height else { return }
        let now = Self.currentOrientation()
        if now != .unknown, now != wideOrientation {
            wideOrientation = now
        }
    }

    /// How far to turn the content so it stays fixed to the device.
    private func counterRotation() -> Double {
        var turn = Self.degrees(wideOrientation) - Self.degrees(Self.currentOrientation())
        if turn > 180 { turn -= 360 }
        if turn <= -180 { turn += 360 }
        // The window is a quarter turn from wide, whatever the system reports.
        return abs(turn) == 90 ? turn : -90
    }

    private static func currentOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }

    /// Clockwise turn of the interface relative to the device.
    private static func degrees(_ orientation: UIInterfaceOrientation) -> Double {
        switch orientation {
        case .landscapeRight: return 90
        case .landscapeLeft: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }

    /// The screen's insets, expressed on the edges of the turned content.
    private static func mapped(_ screen: EdgeInsets, angle: Double) -> EdgeInsets {
        if angle < 0 {
            return EdgeInsets(top: screen.leading, leading: screen.bottom, bottom: screen.trailing, trailing: screen.top)
        }
        return EdgeInsets(top: screen.trailing, leading: screen.top, bottom: screen.leading, trailing: screen.bottom)
    }
}
