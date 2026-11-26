import SwiftUI
import VisionKit

/// The system's live text camera, limited to a box on screen. Text inside
/// the box is highlighted as it is recognised. When `captureTrigger` changes,
/// whatever is recognised at that moment is handed to `onCapture`.
struct LiveTextScanner: UIViewControllerRepresentable {
    /// The scan box, in this view's coordinates.
    let region: CGRect
    let captureTrigger: Int
    let onCapture: ([ScannedBlock]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(trigger: captureTrigger)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if region.width > 0, region.height > 0, controller.regionOfInterest != region {
            controller.regionOfInterest = region
        }
        if !controller.isScanning {
            try? controller.startScanning()
        }
        let coordinator = context.coordinator
        if coordinator.trigger != captureTrigger {
            coordinator.trigger = captureTrigger
            let blocks = coordinator.blocks
            let deliver = onCapture
            // Not during the view update itself.
            DispatchQueue.main.async {
                deliver(blocks)
            }
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var trigger: Int
        private var items: [RecognizedItem] = []

        init(trigger: Int) {
            self.trigger = trigger
        }

        var blocks: [ScannedBlock] {
            items.compactMap { item in
                guard case .text(let text) = item else { return nil }
                return ScannedBlock(text: text.transcript, top: item.bounds.topLeft.y)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
        }
    }
}
