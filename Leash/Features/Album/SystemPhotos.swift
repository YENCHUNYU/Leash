import Photos

/// Copies photos taken in Leash into the iPhone's Photos library, so they're there when choosing a
/// dog photo and survive deleting the app. Uses add-only access: Leash can save, never read.
///
/// Nonisolated on purpose: Photos runs the change block on its own queue, and a block the compiler
/// treats as main-actor code crashes there with a dispatch queue assertion.
nonisolated enum SystemPhotos {
    /// Settings toggle; on by default.
    static let saveKey = "leash.savePhotosToLibrary"

    static var isOn: Bool { UserDefaults.standard.object(forKey: saveKey) as? Bool ?? true }

    /// Returns false if the user declined access or saving failed; the photo is still in Leash's album.
    @discardableResult
    static func save(_ data: Data) async -> Bool {
        guard isOn else { return false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            return true
        } catch {
            return false
        }
    }
}
