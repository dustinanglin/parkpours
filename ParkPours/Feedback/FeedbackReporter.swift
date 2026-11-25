import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted by a shake, or a long press on a page's running header.
    static let feedbackRequested = Notification.Name("parkpours.feedbackRequested")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .feedbackRequested, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

/// What was on screen when the report was started.
struct FeedbackDraft: Identifiable {
    let id = UUID()
    let screenshot: UIImage?
    let context: [String]

    @MainActor
    static func capture() -> FeedbackDraft {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var screenshot: UIImage?
        var context: [String] = []

        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        context.append("App: \(version) (\(build))")
        context.append("iOS: \(UIDevice.current.systemVersion)")
        context.append("Device: \(modelIdentifier())")

        if let window {
            let bounds = window.bounds
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            screenshot = renderer.image { _ in
                window.drawHierarchy(in: bounds, afterScreenUpdates: false)
            }
            let width = Int(bounds.width.rounded())
            let height = Int(bounds.height.rounded())
            let scale = Int(window.screen.scale.rounded())
            let layout = BookLayout.isOpen(bounds.size) ? "open (two-page spread)" : "closed (single page)"
            context.append("Window: \(width) x \(height) pt @\(scale)x")
            context.append("Layout: \(layout)")
        }

        return FeedbackDraft(screenshot: screenshot, context: context)
    }

    private static func modelIdentifier() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafePointer(to: &system.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

/// Listens for a feedback request, grabs the screen, and shows the report sheet.
struct FeedbackReporter: ViewModifier {
    let isActive: Bool
    @State private var draft: FeedbackDraft?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .feedbackRequested)) { _ in
                guard isActive, draft == nil else { return }
                draft = FeedbackDraft.capture()
            }
            .sheet(item: $draft) { draft in
                FeedbackSheet(draft: draft)
                    .preferredColorScheme(.light)
            }
    }
}

extension View {
    /// Only one reporter should be active at a time: the one on the topmost
    /// presented screen.
    func feedbackReporter(isActive: Bool = true) -> some View {
        modifier(FeedbackReporter(isActive: isActive))
    }
}
