import SwiftUI

struct PhotoRef: Identifiable {
    let name: String
    var id: String { name }
}

/// A square thumbnail with a remove button, for the stamp editor.
struct PhotoThumb: View {
    let name: String
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                thumbnail
                    .frame(width: 76, height: 76)
                    .clipped()
                    .overlay {
                        Rectangle().strokeBorder(Theme.ink, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View photo")

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 22, height: 22)
                    .background(Theme.ink)
                    .frame(width: 40, height: 40, alignment: .topTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
        .task(id: name) {
            image = PhotoStore.thumbnail(name)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Theme.rule.opacity(0.25)
        }
    }
}

/// Full-size look at one photo.
struct PhotoViewer: View {
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = PhotoStore.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button("DONE") {
                dismiss()
            }
            .font(Theme.mono(13, weight: .medium))
            .foregroundStyle(.white)
            .frame(minWidth: 64, minHeight: 44)
            .padding(.horizontal, 12)
        }
    }
}
