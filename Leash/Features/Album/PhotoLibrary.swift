import UIKit
import Observation

/// Photos as downscaled JPEG files plus a JSON index, newest first.
@MainActor @Observable
final class PhotoLibrary {
    private(set) var photos: [Photo] = []
    private let directory: URL
    private let index: JSONFile<[Photo]>

    init(directory: URL) throws {
        self.directory = directory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        index = JSONFile("photos.json", in: directory)
        photos = try index.load() ?? []
    }

    func photo(id: UUID) -> Photo? { photos.first { $0.id == id } }

    func url(for photo: Photo, thumbnail: Bool = false) -> URL {
        directory.appendingPathComponent("\(photo.id.uuidString)\(thumbnail ? "-thumb" : "").jpg")
    }

    func image(for photo: Photo, thumbnail: Bool = false) -> UIImage? {
        UIImage(contentsOfFile: url(for: photo, thumbnail: thumbnail).path)
    }

    /// Resizes off the main actor, writes both sizes, then records the photo.
    func add(imageData: Data, walkID: UUID? = nil, spotID: String? = nil) async throws -> Photo {
        let photo = Photo(walkID: walkID, spotID: spotID)
        let full = url(for: photo), thumb = url(for: photo, thumbnail: true)
        try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData) else { throw CocoaError(.fileReadCorruptFile) }
            try Self.jpeg(image, maxSide: 1400).write(to: full, options: .atomic)
            try Self.jpeg(image, maxSide: 360).write(to: thumb, options: .atomic)
        }.value
        let next = [photo] + photos
        do {
            try index.save(next)
        } catch {
            try? FileManager.default.removeItem(at: full)
            try? FileManager.default.removeItem(at: thumb)
            throw error
        }
        photos = next
        return photo
    }

    func delete(_ photo: Photo) throws {
        let next = photos.filter { $0.id != photo.id }
        try index.save(next)
        photos = next
        try? FileManager.default.removeItem(at: url(for: photo))
        try? FileManager.default.removeItem(at: url(for: photo, thumbnail: true))
    }

    nonisolated private static func jpeg(_ image: UIImage, maxSide: CGFloat) throws -> Data {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}
