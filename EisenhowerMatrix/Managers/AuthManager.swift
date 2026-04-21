import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
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

    // MARK: - Delete Account

    /// Deletes the Firebase Auth account. Throws if re-authentication is required
    /// (token too old) — caller should fall back to signOut() in that case.
    func deleteAccount() async throws {
        try await Auth.auth().currentUser?.delete()
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

// MARK: - FriendManager (merged here so Xcode picks it up without adding a new target file)

struct FriendProfile: Identifiable, Equatable {
    var id: String
    var displayName: String
    var photoURL: URL?
    var todayCompleted: Int
    var todayTotal: Int
    var streak: Int
    var lastActiveDate: String  // "yyyy-MM-dd"

    var todayProgress: Double {
        guard todayTotal > 0 else { return 0 }
        return Double(todayCompleted) / Double(todayTotal)
    }
    var isActiveToday: Bool { lastActiveDate == Self.todayStr() }
    static func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

struct FriendRequest: Identifiable {
    var id: String
    var fromUid: String
    var fromName: String
    var fromPhotoURL: URL?
    var createdAt: Date
}

struct SocialNotif: Identifiable {
    var id: String
    var type: String
    var fromName: String
    var fromPhotoURL: URL?
    var createdAt: Date
    var read: Bool

    var emoji: String {
        switch type {
        case "cheer":          return "🔥"
        case "nudge":          return "👋"
        case "friend_request": return "👤"
        case "accepted":       return "🎉"
        default:               return "•"
        }
    }
    var message: String {
        switch type {
        case "cheer":          return "\(fromName) cheered you on!"
        case "nudge":          return "\(fromName) sent you a nudge!"
        case "friend_request": return "\(fromName) wants to be friends"
        case "accepted":       return "\(fromName) accepted your request"
        default:               return fromName
        }
    }
}

@MainActor
final class FriendManager: ObservableObject {
    static let shared = FriendManager()
    private init() {}

    @Published var friends: [FriendProfile]          = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var notifications: [SocialNotif]      = []
    @Published var unreadCount: Int                  = 0
    @Published var isSendingRequest                  = false
    @Published var requestError: String?             = nil

    private let db = Firestore.firestore()
    private var mainListeners:    [ListenerRegistration]          = []
    private var profileListeners: [String: ListenerRegistration]  = [:]

    // MARK: - Lifecycle

    func start(uid: String) {
        stopAll()
        listenFriends(uid: uid)
        listenIncomingRequests(uid: uid)
        listenNotifications(uid: uid)
    }

    func stopAll() {
        mainListeners.forEach { $0.remove() }
        mainListeners = []
        profileListeners.values.forEach { $0.remove() }
        profileListeners = [:]
        friends = []; incomingRequests = []; notifications = []; unreadCount = 0
    }

    // MARK: - Listeners

    private func listenFriends(uid: String) {
        let reg = db.collection("users").document(uid).collection("friends")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let uids = snap?.documents.compactMap { $0.data()["uid"] as? String } ?? []
                for fuid in uids where self.profileListeners[fuid] == nil { self.listenProfile(fuid) }
                for fuid in Array(self.profileListeners.keys) where !uids.contains(fuid) {
                    self.profileListeners[fuid]?.remove()
                    self.profileListeners.removeValue(forKey: fuid)
                    self.friends.removeAll { $0.id == fuid }
                }
            }
        mainListeners.append(reg)
    }

    private func listenProfile(_ uid: String) {
        let reg = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                let p = FriendProfile(
                    id: uid,
                    displayName:    data["displayName"]    as? String ?? "Unknown",
                    photoURL:       (data["photoURL"]      as? String).flatMap(URL.init),
                    todayCompleted: data["todayCompleted"] as? Int    ?? 0,
                    todayTotal:     data["todayTotal"]     as? Int    ?? 0,
                    streak:         data["streak"]         as? Int    ?? 0,
                    lastActiveDate: data["lastActiveDate"] as? String ?? ""
                )
                if let idx = self.friends.firstIndex(where: { $0.id == uid }) {
                    self.friends[idx] = p
                } else {
                    self.friends.append(p)
                }
            }
        profileListeners[uid] = reg
    }

    private func listenIncomingRequests(uid: String) {
        let reg = db.collection("friendRequests")
            .whereField("toUid",  isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.incomingRequests = snap?.documents.compactMap { doc -> FriendRequest? in
                    let d = doc.data()
                    guard let from = d["fromUid"] as? String else { return nil }
                    return FriendRequest(
                        id: doc.documentID,
                        fromUid:      from,
                        fromName:     d["fromName"]     as? String ?? "Unknown",
                        fromPhotoURL: (d["fromPhotoURL"] as? String).flatMap(URL.init),
                        createdAt:   (d["createdAt"]    as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
            }
        mainListeners.append(reg)
    }

    private func listenNotifications(uid: String) {
        let reg = db.collection("users").document(uid).collection("notifications")
            .order(by: "createdAt", descending: true).limit(to: 30)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.notifications = snap?.documents.map { doc -> SocialNotif in
                    let d = doc.data()
                    return SocialNotif(
                        id:           doc.documentID,
                        type:         d["type"]         as? String ?? "",
                        fromName:     d["fromName"]     as? String ?? "",
                        fromPhotoURL: (d["fromPhotoURL"] as? String).flatMap(URL.init),
                        createdAt:   (d["createdAt"]    as? Timestamp)?.dateValue() ?? Date(),
                        read:         d["read"]         as? Bool   ?? false
                    )
                } ?? []
                self.unreadCount = self.notifications.filter { !$0.read }.count
            }
        mainListeners.append(reg)
    }

    // MARK: - Public stats

    func updateStats(uid: String, todayCompleted: Int, todayTotal: Int, streak: Int) {
        db.collection("users").document(uid).setData([
            "todayCompleted": todayCompleted,
            "todayTotal":     todayTotal,
            "streak":         streak,
            "lastActiveDate": FriendProfile.todayStr()
        ], merge: true)
    }

    func writeProfile(uid: String, displayName: String, email: String, photoURL: String?) {
        var data: [String: Any] = ["displayName": displayName, "email": email]
        if let url = photoURL { data["photoURL"] = url }
        db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - Friend requests

    func sendFriendRequest(toEmail: String, myUid: String, myName: String, myPhotoURL: String?) async {
        isSendingRequest = true; requestError = nil
        defer { isSendingRequest = false }
        do {
            let snap = try await db.collection("users")
                .whereField("email", isEqualTo: toEmail.lowercased().trimmingCharacters(in: .whitespaces))
                .limit(to: 1).getDocuments()
            guard let targetDoc = snap.documents.first else { requestError = "No user found with that email."; return }
            let toUid = targetDoc.documentID
            guard toUid != myUid else { requestError = "You cannot add yourself."; return }
            let alreadyFriend = try await db.collection("users").document(myUid).collection("friends").document(toUid).getDocument()
            if alreadyFriend.exists { requestError = "Already friends!"; return }
            let existingReq = try await db.collection("friendRequests")
                .whereField("fromUid", isEqualTo: myUid).whereField("toUid", isEqualTo: toUid).whereField("status", isEqualTo: "pending")
                .getDocuments()
            if !existingReq.documents.isEmpty { requestError = "Request already sent."; return }
            let reqRef = db.collection("friendRequests").document()
            try await reqRef.setData(["fromUid": myUid, "fromName": myName, "fromPhotoURL": myPhotoURL ?? "",
                                      "toUid": toUid, "toEmail": toEmail, "status": "pending", "createdAt": Timestamp()])
            try await db.collection("users").document(toUid).collection("notifications").document()
                .setData(["type": "friend_request", "fromUid": myUid, "fromName": myName,
                          "fromPhotoURL": myPhotoURL ?? "", "requestId": reqRef.documentID,
                          "createdAt": Timestamp(), "read": false])
        } catch { requestError = error.localizedDescription }
    }

    func acceptRequest(_ req: FriendRequest, myUid: String, myName: String, myPhotoURL: String?) async {
        do {
            try await db.collection("friendRequests").document(req.id).setData(["status": "accepted"], merge: true)
            try await db.collection("users").document(myUid).collection("friends").document(req.fromUid)
                .setData(["uid": req.fromUid, "addedAt": Timestamp()])
            try await db.collection("users").document(req.fromUid).collection("friends").document(myUid)
                .setData(["uid": myUid, "addedAt": Timestamp()])
            try await db.collection("users").document(req.fromUid).collection("notifications").document()
                .setData(["type": "accepted", "fromUid": myUid, "fromName": myName,
                          "fromPhotoURL": myPhotoURL ?? "", "createdAt": Timestamp(), "read": false])
        } catch {}
    }

    func declineRequest(_ req: FriendRequest) {
        db.collection("friendRequests").document(req.id).setData(["status": "declined"], merge: true)
    }

    func removeFriend(friendUid: String, myUid: String) {
        db.collection("users").document(myUid).collection("friends").document(friendUid).delete()
        db.collection("users").document(friendUid).collection("friends").document(myUid).delete()
    }

    // MARK: - Cheer / Nudge

    func sendCheer(to friend: FriendProfile, fromUid: String, fromName: String, fromPhotoURL: String?) {
        db.collection("users").document(friend.id).collection("notifications").document()
            .setData(["type": "cheer", "fromUid": fromUid, "fromName": fromName,
                      "fromPhotoURL": fromPhotoURL ?? "", "createdAt": Timestamp(), "read": false])
    }

    func sendNudge(to friend: FriendProfile, fromUid: String, fromName: String, fromPhotoURL: String?) {
        db.collection("users").document(friend.id).collection("notifications").document()
            .setData(["type": "nudge", "fromUid": fromUid, "fromName": fromName,
                      "fromPhotoURL": fromPhotoURL ?? "", "createdAt": Timestamp(), "read": false])
    }

    func markAllRead(uid: String) {
        let col = db.collection("users").document(uid).collection("notifications")
        for notif in notifications where !notif.read { col.document(notif.id).setData(["read": true], merge: true) }
        unreadCount = 0
    }
}
