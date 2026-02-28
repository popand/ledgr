import Foundation
import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {

    let llmService: LLMService
    let authService: AuthService
    let googleDriveService: GoogleDriveService
    let googleSheetsService: GoogleSheetsService
    let uploadQueueService: UploadQueueService

    init() {
        self.llmService = LLMService()
        self.authService = AuthService()
        self.googleDriveService = GoogleDriveService()
        self.googleSheetsService = GoogleSheetsService()
        self.uploadQueueService = UploadQueueService()
    }
}
