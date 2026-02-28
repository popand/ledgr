import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class CameraViewModel: ObservableObject {

    @Published var selectedImage: UIImage?
    @Published var isShowingCamera = false
    @Published var isShowingPhotoPicker = false
    @Published var capturedImageData: Data?
    @Published var selectedPhotoItem: PhotosPickerItem?

    func handleCapturedImage(_ image: UIImage) {
        selectedImage = image
        capturedImageData = image.jpegData(compressionQuality: 0.8)
    }

    func handlePhotoPickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }
            selectedImage = image
            capturedImageData = image.jpegData(compressionQuality: 0.8)
        } catch {
            selectedImage = nil
            capturedImageData = nil
        }
    }

    func clearSelection() {
        selectedImage = nil
        capturedImageData = nil
        selectedPhotoItem = nil
    }
}
