import Foundation

enum LedgrError: LocalizedError {
    case llmExtractionFailed(String)
    case googleAuthFailed(String)
    case driveUploadFailed(String)
    case sheetsAppendFailed(String)
    case keychainError(String)
    case imageProcessingFailed(String)
    case networkUnavailable
    case invalidResponse
    case sheetsReadFailed(String)
    case insightGenerationFailed(String)
    case driveDeleteFailed(String)
    case sheetsDeleteFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .llmExtractionFailed(let message):
            return "Failed to extract receipt data: \(message)"
        case .googleAuthFailed(let message):
            return "Google authentication failed: \(message)"
        case .driveUploadFailed(let message):
            return "Google Drive upload failed: \(message)"
        case .sheetsAppendFailed(let message):
            return "Google Sheets update failed: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .imageProcessingFailed(let message):
            return "Image processing failed: \(message)"
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .invalidResponse:
            return "Received an invalid response"
        case .sheetsReadFailed(let message):
            return "Failed to read from Google Sheets: \(message)"
        case .insightGenerationFailed(let message):
            return "Failed to generate insights: \(message)"
        case .driveDeleteFailed(let message):
            return "Failed to delete file from Google Drive: \(message)"
        case .sheetsDeleteFailed(let message):
            return "Failed to delete row from Google Sheets: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
