import PhotosUI
import SwiftUI
import VisionKit

/// Scan a menu, tick the drinks, and add them to a park as personal drinks.
struct MenuScanSheet: View {
    let park: Park

    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    @State private var lines: [ScanLine] = []
    @State private var venue = ""
    @State private var isReading = false
    @State private var hasScanned = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    private var selected: [ScanLine] {
        lines.filter { $0.isSelected && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                if hasScanned {
                    if lines.isEmpty {
                        Section {
                            Text("No text found. Try again closer to the menu, with less glare.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Where is this menu?") {
                            TextField("Bar or restaurant (optional)", text: $venue)
                        }
                        linesSection
                    }
                }
            }
            .navigationTitle("Scan a menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add \(selected.count)", action: addSelected)
                        .disabled(selected.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCamera(isPresented: $showCamera) { images in
                    read(images)
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        read([image])
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        Section {
            if VNDocumentCameraViewController.isSupported {
                Button {
                    showCamera = true
                } label: {
                    Label("Scan with the camera", systemImage: "camera")
                }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo")
            }
            if isReading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the menu…")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("The text is read on your phone. The photo is not saved or sent anywhere.")
        }
    }

    private var linesSection: some View {
        Section {
            ForEach($lines) { $line in
                HStack(spacing: 12) {
                    Button {
                        line.isSelected.toggle()
                    } label: {
                        Image(systemName: line.isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(line.isSelected ? Theme.cover : Color.secondary)
                    .accessibilityLabel(line.isSelected ? "Selected" : "Not selected")

                    TextField("Drink name", text: $line.text)
                }
            }
        } header: {
            Text("Tick the drinks to add to \(park.name)")
        } footer: {
            Text("Names can be corrected before adding. Added drinks are yours only; they are not part of the official catalog.")
        }
    }

    private func read(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        isReading = true
        Task {
            let found = await MenuTextReader.lines(in: images)
            let known = Set(lines.map { $0.text.lowercased() })
            lines += found
                .filter { !known.contains($0.lowercased()) }
                .map { ScanLine(text: $0) }
            isReading = false
            hasScanned = true
        }
    }

    private func addSelected() {
        for line in selected {
            store.addDrink(name: line.text, venue: venue, to: park)
        }
        dismiss()
    }
}

struct ScanLine: Identifiable {
    let id = UUID()
    var text: String
    var isSelected = false
}

/// The system document camera: finds the page edges and straightens it.
struct DocumentCamera: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onScan: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentCamera

        init(_ parent: DocumentCamera) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.isPresented = false
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.isPresented = false
        }
    }
}
