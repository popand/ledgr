import Foundation
import UIKit

// NOTE: Add GoogleSignIn SPM package to enable real authentication.
// SPM URL: https://github.com/google/GoogleSignIn-iOS
// Once added, set GOOGLE_SIGNIN_AVAILABLE in build settings active compilation conditions.

#if canImport(GoogleSignIn)
import GoogleSignIn
private let googleSignInAvailable = true
#else
private let googleSignInAvailable = false
#endif

final class AuthService: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?

    private var accessToken: String?

    private let requiredScopes = [
        "https://www.googleapis.com/auth/drive.file",
        "https://www.googleapis.com/auth/spreadsheets"
    ]

    // MARK: - Public

    @MainActor
    func signIn(presenting viewController: UIViewController) async throws {
        #if canImport(GoogleSignIn)
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

            accessToken = user.accessToken.tokenString
            userEmail = user.profile?.email
            isAuthenticated = true
        } catch let error as LedgrError {
            throw error
        } catch {
            throw LedgrError.googleAuthFailed(error.localizedDescription)
        }
        #else
        throw LedgrError.googleAuthFailed(
            "Google Sign-In SDK not installed. Add the GoogleSignIn-iOS SPM package to enable authentication."
        )
        #endif
    }

    @MainActor
    func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        accessToken = nil
        isAuthenticated = false
        userEmail = nil
    }

    func getAccessToken() async throws -> String {
        #if canImport(GoogleSignIn)
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
        #else
        guard let token = accessToken, !token.isEmpty else {
            throw LedgrError.googleAuthFailed("Not authenticated")
        }
        return token
        #endif
    }

    @MainActor
    func restorePreviousSignIn() async {
        #if canImport(GoogleSignIn)
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let grantedScopes = user.grantedScopes ?? []
            let hasAllScopes = requiredScopes.allSatisfy { scope in
                grantedScopes.contains(scope)
            }

            if hasAllScopes {
                accessToken = user.accessToken.tokenString
                userEmail = user.profile?.email
                isAuthenticated = true
            }
        } catch {
            isAuthenticated = false
            userEmail = nil
        }
        #endif
    }
}
