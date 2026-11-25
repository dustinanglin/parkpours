import UIKit

/// Drink photos live as JPEG files in Documents/photos on the device.
/// A stamp only stores the file names.
enum PhotoStore {
    private static var folder: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("photos", isDirectory: true)
    }

    static func url(for name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// Saves a picked image, scaled down to a sensible size. Returns its file name.
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let jpeg = scaled(image, maxDimension: 1600).jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = UUID().uuidString + ".jpg"
            try jpeg.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: name).path)
    }

    static func thumbnail(_ name: String) -> UIImage? {
        image(name).map { scaled($0, maxDimension: 320) }
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }

    private static func scaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
