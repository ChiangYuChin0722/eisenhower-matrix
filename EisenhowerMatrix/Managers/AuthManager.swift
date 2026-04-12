import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var user: FirebaseAuth.User? = nil
    @Published var isLoading = true

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user     = user
                self?.isLoading = false
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var isSignedIn: Bool { user != nil }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingConfig
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC      = windowScene.windows.first?.rootViewController
        else { throw AuthError.noViewController }

        let result      = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Apple Sign In

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce    = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let auth):
            guard let appleCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce      = currentNonce,
                  let tokenData  = appleCredential.identityToken,
                  let tokenStr   = String(data: tokenData, encoding: .utf8)
            else { throw AuthError.invalidCredential }

            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenStr,
                rawNonce:    nonce,
                fullName:    appleCredential.fullName
            )
            try await Auth.auth().signIn(with: credential)

        case .failure(let error):
            throw error
        }
    }

    // MARK: - Update Profile

    func updateProfile(displayName: String) async {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let req = firebaseUser.createProfileChangeRequest()
        req.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await req.commitChanges()
        self.user = Auth.auth().currentUser
    }

    // MARK: - Local avatar helpers

    private static var localAvatarURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_avatar.jpg")
    }

    static func saveLocalAvatar(_ data: Data) {
        try? data.write(to: localAvatarURL)
    }

    static func loadLocalAvatar() -> UIImage? {
        guard let data = try? Data(contentsOf: localAvatarURL) else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    func avatarView(size: CGFloat) -> some View {
        if let img = AuthManager.loadLocalAvatar() {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let url = user?.photoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: size))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: size))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Auth errors

enum AuthError: LocalizedError {
    case missingConfig, noViewController, invalidCredential

    var errorDescription: String? {
        switch self {
        case .missingConfig:     return "Firebase is not configured. Add GoogleService-Info.plist."
        case .noViewController:  return "Cannot find root view controller."
        case .invalidCredential: return "Invalid credentials received."
        }
    }
}
