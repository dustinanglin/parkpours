import AVFoundation
import SwiftUI
import VisionKit

/// Scan one drink at a time: frame its name and description in the box,
/// capture, check what was read, and add it to the park as a personal drink.
struct MenuScanSheet: View {
    let park: Park

    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    private enum Stage {
        case checking
        case camera
        case review
        case unavailable
    }

    @State private var stage: Stage = .checking
    @State private var captureTrigger = 0
    @State private var emptyCapture = false
    @State private var lines: [String] = []
    @State private var name = ""
    @State private var details = ""
    @State private var venue = ""
    @State private var nonAlcoholic = false
    @State private var addedCount = 0

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(stage == .review ? "Check the drink" : "Scan a drink")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(addedCount == 0 ? "Cancel" : "Done") {
                            dismiss()
                        }
                    }
                    if stage == .review {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                add(thenScanAgain: false)
                            }
                            .disabled(trimmedName.isEmpty)
                        }
                    }
                }
        }
        .task {
            await checkCamera()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .camera:
            cameraStage
        case .review, .unavailable:
            reviewForm
        }
    }

    // MARK: Camera

    private var cameraStage: some View {
        GeometryReader { geo in
            let box = Self.scanBox(in: geo.size)
            ZStack {
                LiveTextScanner(region: box, captureTrigger: captureTrigger) { blocks in
                    review(blocks)
                }

                // Dim everything outside the box.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(box)
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
                    .allowsHitTesting(false)

                VStack(spacing: 12) {
                    Text(emptyCapture
                         ? "No text was in the box. Move closer and hold steady."
                         : "Fit one drink's name and description in the box. Pinch to zoom.")
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    if addedCount > 0 {
                        Text("\(addedCount) added to \(park.name)")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Button {
                        emptyCapture = false
                        captureTrigger += 1
                    } label: {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 68, height: 68)
                            Circle().strokeBorder(Color.black.opacity(0.8), lineWidth: 2).frame(width: 58, height: 58)
                        }
                        .frame(width: 80, height: 80)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture the text in the box")
                    Button("Type it in instead") {
                        startReview(with: DrinkTextParser.Result(name: "", details: "", lines: []))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.black)
    }

    /// A wide box across the upper middle of the view: a drink entry on a
    /// menu is a short stack of wide lines.
    private static func scanBox(in size: CGSize) -> CGRect {
        let width = max(size.width - 32, 0)
        let height = min(width * 0.5, size.height * 0.4)
        return CGRect(x: 16, y: size.height * 0.38 - height / 2, width: width, height: height)
    }

    private func checkCamera() async {
        guard stage == .checking else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted, DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            stage = .camera
        } else {
            stage = .unavailable
        }
    }

    private func review(_ blocks: [ScannedBlock]) {
        let result = DrinkTextParser.parse(blocks)
        if result.lines.isEmpty {
            emptyCapture = true
        } else {
            startReview(with: result)
        }
    }

    private func startReview(with result: DrinkTextParser.Result) {
        lines = result.lines
        name = result.name
        details = result.details
        nonAlcoholic = false
        stage = .review
    }

    // MARK: Review

    private var reviewForm: some View {
        Form {
            if stage == .unavailable {
                Section {
                    Text("The camera scanner is not available. Check that Park Pours is allowed to use the camera in Settings, or type the drink in below.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Drink name", text: $name)
                TextField("Description (optional)", text: $details, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Bar or restaurant (optional)", text: $venue)
                Toggle("Non-alcoholic", isOn: $nonAlcoholic)
            } header: {
                Text("Adding to \(park.name)")
            } footer: {
                Text("Fix anything the camera got wrong. The drink is yours only; it is not part of the official catalog.")
            }

            if lines.count > 1 {
                Section {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Button {
                            let result = DrinkTextParser.split(lines, nameIndex: index)
                            name = result.name
                            details = result.details
                        } label: {
                            Text(line)
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } header: {
                    Text("Wrong name? Tap the line that is the name")
                }
            }

            if stage == .review {
                Section {
                    Button("Add and scan another") {
                        add(thenScanAgain: true)
                    }
                    .disabled(trimmedName.isEmpty)
                    Button("Scan again without adding") {
                        emptyCapture = false
                        stage = .camera
                    }
                }
            } else {
                Section {
                    Button("Add drink") {
                        add(thenScanAgain: false)
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func add(thenScanAgain: Bool) {
        guard !trimmedName.isEmpty else { return }
        store.addDrink(name: trimmedName, venue: venue, details: details, nonAlcoholic: nonAlcoholic, to: park)
        addedCount += 1
        if thenScanAgain {
            // The venue is kept: the next drink is usually on the same menu.
            emptyCapture = false
            stage = .camera
        } else {
            dismiss()
        }
    }
}
