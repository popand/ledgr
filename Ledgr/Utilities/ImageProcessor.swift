import UIKit

struct ImageProcessor {

    static func compressImage(_ image: UIImage, maxSizeBytes: Int = 1_048_576) -> Data? {
        var compressionQuality: CGFloat = 0.9
        let minQuality: CGFloat = 0.1
        let step: CGFloat = 0.1

        var resizedImage = image
        let maxDimension: CGFloat = 2048
        if max(image.size.width, image.size.height) > maxDimension {
            resizedImage = resizeImage(image, maxDimension: maxDimension)
        }

        guard var data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }

        while data.count > maxSizeBytes && compressionQuality > minQuality {
            compressionQuality -= step
            guard let newData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
                return nil
            }
            data = newData
        }

        return data.count <= maxSizeBytes ? data : nil
    }

    static func base64Encode(_ data: Data) -> String {
        data.base64EncodedString()
    }

    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
