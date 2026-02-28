import Foundation
import SwiftUI
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var isGoogleConnected = false
    @Published var userEmail: String?
    @Published var apiKeySet = false
    @Published var defaultCurrency: String
    @Published var driveFolderName: String
    @Published var sheetsName: String
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
        self.defaultCurrency = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultCurrency) ?? "CAD"
        self.driveFolderName = UserDefaults.standard.string(forKey: UserDefaultsKeys.driveFolderName) ?? APIConstants.defaultDriveFolderName
        self.sheetsName = UserDefaults.standard.string(forKey: UserDefaultsKeys.sheetsName) ?? APIConstants.defaultSheetsName

        refreshState()
    }

    func refreshState() {
        isGoogleConnected = authService.isAuthenticated
        userEmail = authService.userEmail
        checkApiKeyStatus()
    }

    // MARK: - Google Auth

    func connectGoogle() async {
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let viewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present sign-in"
            return
        }

        do {
            try await authService.signIn(presenting: viewController)
            isGoogleConnected = authService.isAuthenticated
            userEmail = authService.userEmail
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectGoogle() {
        authService.signOut()
        isGoogleConnected = false
        userEmail = nil
    }

    // MARK: - API Key

    func saveApiKey(_ key: String) {
        guard !key.isEmpty else {
            errorMessage = "API key cannot be empty"
            return
        }

        do {
            try KeychainManager.saveString(key, forKey: KeychainKeys.anthropicAPIKey)
            apiKeySet = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearApiKey() {
        do {
            try KeychainManager.delete(key: KeychainKeys.anthropicAPIKey)
            apiKeySet = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkApiKeyStatus() {
        do {
            let key = try KeychainManager.loadString(forKey: KeychainKeys.anthropicAPIKey)
            apiKeySet = key != nil && !(key?.isEmpty ?? true)
        } catch {
            apiKeySet = false
        }
    }

    // MARK: - Preferences

    func saveCurrency() {
        UserDefaults.standard.set(defaultCurrency, forKey: UserDefaultsKeys.defaultCurrency)
    }

    func saveFolderName() {
        UserDefaults.standard.set(driveFolderName, forKey: UserDefaultsKeys.driveFolderName)
    }

    func saveSheetsName() {
        UserDefaults.standard.set(sheetsName, forKey: UserDefaultsKeys.sheetsName)
    }
}
