import SwiftUI
import UIKit

/// One leaf of the passport.
struct BookPage: Identifiable {
    let id: String
    let view: AnyView
}

/// Swipe through pages with a paper page-turn. Open, it shows two pages with
/// the spine in the middle; closed, one page at a time.
///
/// The spine position is fixed when the controller is created, so give this
/// view a new `.id` whenever `isOpen` or the set of pages changes wholesale.
struct BookPager: UIViewControllerRepresentable {
    let pages: [BookPage]
    let isOpen: Bool
    @Binding var index: Int

    init(pages: [BookPage], isOpen: Bool, index: Binding<Int>) {
        var all = pages
        if all.isEmpty || (isOpen && all.count % 2 == 1) {
            // A two-page spread needs an even number of pages.
            all.append(BookPage(id: "endpaper", view: AnyView(PaperBackground())))
        }
        self.pages = all
        self.isOpen = isOpen
        self._index = index
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let spine: UIPageViewController.SpineLocation = isOpen ? .mid : .min
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: spine.rawValue)]
        )
        controller.isDoubleSided = isOpen
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = UIColor(Theme.paper)
        // Page curl also turns the page on a tap near the edge, which steals
        // taps from rows and buttons. Swipes are enough.
        for recognizer in controller.gestureRecognizers where recognizer is UITapGestureRecognizer {
            recognizer.isEnabled = false
        }
        context.coordinator.sync(controller)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(controller)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: BookPager
        private var hosts: [String: UIHostingController<AnyView>] = [:]

        init(_ parent: BookPager) {
            self.parent = parent
        }

        private func host(at position: Int) -> UIViewController? {
            guard parent.pages.indices.contains(position) else { return nil }
            let page = parent.pages[position]
            if let existing = hosts[page.id] {
                return existing
            }
            let host = UIHostingController(rootView: page.view)
            host.view.backgroundColor = UIColor(Theme.paper)
            hosts[page.id] = host
            return host
        }

        private func position(of controller: UIViewController) -> Int? {
            guard let id = hosts.first(where: { $0.value === controller })?.key else { return nil }
            return parent.pages.firstIndex { $0.id == id }
        }

        private func visible(from position: Int) -> [UIViewController] {
            if parent.isOpen {
                let first = position - position % 2
                return [host(at: first), host(at: first + 1)].compactMap { $0 }
            }
            return [host(at: position)].compactMap { $0 }
        }

        /// Refreshes page content and makes sure the right pages are showing.
        func sync(_ controller: UIPageViewController) {
            let ids = Set(parent.pages.map { $0.id })
            hosts = hosts.filter { ids.contains($0.key) }
            for page in parent.pages {
                hosts[page.id]?.rootView = page.view
            }

            let position = min(max(parent.index, 0), parent.pages.count - 1)
            let wanted = visible(from: position)
            let current = controller.viewControllers ?? []
            let same = wanted.count == current.count && zip(wanted, current).allSatisfy { $0 === $1 }
            if !same, wanted.count == (parent.isOpen ? 2 : 1) {
                // A change of page asked for in code (opening the cover,
                // "close book") turns the page like a swipe would. A refresh
                // of the same spread, or the first display, does not animate.
                let showing = current.first.flatMap { self.position(of: $0) }
                let target = wanted.first.flatMap { self.position(of: $0) }
                var animated = false
                var direction = UIPageViewController.NavigationDirection.forward
                if let showing, let target, showing != target, controller.view.window != nil {
                    animated = true
                    direction = target > showing ? .forward : .reverse
                }
                controller.setViewControllers(wanted, direction: direction, animated: animated)
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let position = position(of: viewController) else { return nil }
            return host(at: position - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let position = position(of: viewController) else { return nil }
            return host(at: position + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let first = pageViewController.viewControllers?.first,
                  let position = position(of: first) else { return }
            if parent.index != position {
                parent.index = position
            }
        }
    }
}

/// Two fixed pages either side of the fold, for screens that do not page
/// (the stamp editor). Stays put when the keyboard appears.
struct BookSpread<Left: View, Right: View>: View {
    private let left: Left
    private let right: Right

    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            HStack(spacing: 0) {
                left
                    .padding(.leading, insets.leading)
                    .frame(width: geo.size.width / 2)
                right
                    .padding(.trailing, insets.trailing)
                    .frame(width: geo.size.width / 2)
            }
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .ignoresSafeArea(.keyboard)
        .overlay {
            SpineShadow()
        }
    }
}
