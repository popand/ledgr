import Foundation
import UIKit
import GoogleSignIn

final class AuthService: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?

    private let requiredScopes = [
        "https://www.googleapis.com/auth/drive.file"
    ]

    // MARK: - Public

    @MainActor
    func signIn(presenting viewController: UIViewController) async throws {
        // GIDSignIn crashes with NSException if no client ID is configured.
        // Check before calling to prevent a fatal crash.
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            throw LedgrError.googleAuthFailed(
                "Google Sign-In is not configured. Add your GIDClientID to Info.plist. " +
                "See README.md for setup instructions."
            )
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: requiredScopes
            )

            let user = result.user
            guard user.accessToken.tokenString.isEmpty == false else {
                throw LedgrError.googleAuthFailed("No access token received")
            }

            userEmail = user.profile?.email
            isAuthenticated = true
        } catch let error as LedgrError {
            throw error
        } catch {
            throw LedgrError.googleAuthFailed(error.localizedDescription)
        }
    }

    @MainActor
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        userEmail = nil
    }

    func getAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw LedgrError.googleAuthFailed("No signed-in user")
        }

        do {
            try await currentUser.refreshTokensIfNeeded()
        } catch {
            throw LedgrError.googleAuthFailed("Token refresh failed: \(error.localizedDescription)")
        }

        let token = currentUser.accessToken.tokenString
        guard !token.isEmpty else {
            throw LedgrError.googleAuthFailed("Access token is empty after refresh")
        }

        return token
    }

    @MainActor
    func restorePreviousSignIn() async {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let grantedScopes = user.grantedScopes ?? []
            let hasAllScopes = requiredScopes.allSatisfy { scope in
                grantedScopes.contains(scope)
            }

            if hasAllScopes {
                userEmail = user.profile?.email
                isAuthenticated = true
            }
        } catch {
            isAuthenticated = false
            userEmail = nil
        }
    }
}
