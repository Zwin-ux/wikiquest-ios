import AuthenticationServices
import CryptoKit
import Foundation
import Security

@MainActor
final class SessionStore: ObservableObject {
    @Published var isSignedIn = false
    @Published var displayName = "Explorer"
    @Published var statusText = "Signed out"
    @Published var isSigningIn = false
    @Published var lastAuthError: String?

    private(set) var accountUserId: String?
    private var sessionToken: String?
    private var currentNonce: String?
    private var developmentToken: String?

    init() {
        developmentToken = ProcessInfo.processInfo.environment["WIKIQUEST_SESSION_TOKEN"]
        sessionToken = KeychainStore.read("session_token") ?? developmentToken
        accountUserId = KeychainStore.read("user_id")
        displayName = KeychainStore.read("display_name") ?? "Explorer"
        if sessionToken != nil {
            isSignedIn = true
            statusText = developmentToken != nil ? "Using local WikiQuest session." : "Signed in with Apple."
        }
    }

    func bearerToken() async -> String? {
        sessionToken
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try Self.randomNonce()
            let hashedNonce = Self.sha256(nonce)
            currentNonce = hashedNonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            statusText = "Opening Sign in with Apple."
            lastAuthError = nil
            Haptics.light()
        } catch {
            currentNonce = nil
            lastAuthError = error.localizedDescription
            statusText = "Apple sign-in could not start."
            Haptics.error()
        }
    }

    func handleAppleCompletion(
        _ result: Result<ASAuthorization, Error>,
        api: WikiQuestAPIClient
    ) {
        Task { await finishAppleCompletion(result, api: api) }
    }

    func signOut() {
        KeychainStore.delete("session_token")
        KeychainStore.delete("user_id")
        KeychainStore.delete("display_name")
        sessionToken = nil
        accountUserId = nil
        developmentToken = nil
        isSignedIn = false
        isSigningIn = false
        displayName = "Explorer"
        statusText = "Signed out"
        Haptics.light()
    }

    func validateAppleCredentialState() async {
        guard
            isSignedIn,
            developmentToken == nil,
            let accountUserId,
            accountUserId.hasPrefix("apple:")
        else {
            return
        }

        let appleUserId = String(accountUserId.dropFirst("apple:".count))
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserId) { [weak self] state, error in
                Task { @MainActor in
                    if let error {
                        self?.lastAuthError = error.localizedDescription
                    }
                    switch state {
                    case .authorized:
                        self?.statusText = "Signed in with Apple."
                    case .revoked, .notFound, .transferred:
                        self?.statusText = "Apple sign-in expired."
                        self?.lastAuthError = "Sign in again to continue."
                        self?.signOut()
                    @unknown default:
                        break
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func finishAppleCompletion(
        _ result: Result<ASAuthorization, Error>,
        api: WikiQuestAPIClient
    ) async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let credential = try appleCredential(from: result)
            guard
                let identityTokenData = credential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                throw AuthFlowError.missingIdentityToken
            }

            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }
            guard let nonce = currentNonce else {
                throw AuthFlowError.missingNonce
            }
            let name = displayName(from: credential.fullName)
            let response = try await api.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce,
                email: credential.email,
                displayName: name
            )

            sessionToken = response.token
            accountUserId = response.userId
            displayName = response.displayName
            isSignedIn = true
            statusText = "Signed in with Apple."
            lastAuthError = nil
            KeychainStore.save(response.token, account: "session_token")
            KeychainStore.save(response.userId, account: "user_id")
            KeychainStore.save(response.displayName, account: "display_name")
            Haptics.success()
        } catch {
            if Self.isAppleCancellation(error) {
                lastAuthError = nil
                statusText = "Sign in canceled."
                Haptics.light()
            } else {
                lastAuthError = error.localizedDescription
                statusText = "Apple sign-in failed."
                Haptics.error()
            }
        }
    }

    private func appleCredential(from result: Result<ASAuthorization, Error>) throws -> ASAuthorizationAppleIDCredential {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthFlowError.unsupportedCredential
            }
            return credential
        case .failure(let error):
            throw error
        }
    }

    private func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let value = PersonNameComponentsFormatter().string(from: components)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sha256(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                throw AuthFlowError.secureRandomUnavailable
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func isAppleCancellation(_ error: Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else { return false }
        return authorizationError.code == .canceled
    }
}

private enum AuthFlowError: LocalizedError {
    case missingNonce
    case missingIdentityToken
    case secureRandomUnavailable
    case unsupportedCredential

    var errorDescription: String? {
        switch self {
        case .missingNonce:
            return "Apple sign-in was not prepared securely. Try again."
        case .missingIdentityToken:
            return "Apple did not return an identity token."
        case .secureRandomUnavailable:
            return "WikiQuest could not create a secure Apple sign-in request."
        case .unsupportedCredential:
            return "Apple returned an unsupported credential."
        }
    }
}
