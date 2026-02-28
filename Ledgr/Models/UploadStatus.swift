import Foundation

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case complete
    case failed
}
