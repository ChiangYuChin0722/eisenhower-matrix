import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Models

struct FriendProfile: Identifiable, Equatable {
    var id: String          // Firebase uid
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
    var type: String        // "cheer" | "nudge" | "friend_request" | "accepted"
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

// MARK: - Manager

@MainActor
final class FriendManager: ObservableObject {
    static let shared = FriendManager()
    private init() {}

    @Published var friends: [FriendProfile]       = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var notifications: [SocialNotif]   = []
    @Published var unreadCount: Int                = 0
    @Published var isSendingRequest                = false
    @Published var requestError: String?           = nil

    private let db = Firestore.firestore()
    private var mainListeners: [ListenerRegistration]         = []
    private var profileListeners: [String: ListenerRegistration] = [:]

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
        friends = []
        incomingRequests = []
        notifications = []
        unreadCount = 0
    }

    // MARK: - Listeners

    private func listenFriends(uid: String) {
        let reg = db.collection("users").document(uid)
            .collection("friends")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let uids = snap?.documents.compactMap { $0.data()["uid"] as? String } ?? []

                // Start listeners for newly added friends
                for fuid in uids where self.profileListeners[fuid] == nil {
                    self.listenProfile(fuid)
                }
                // Remove listeners for removed friends
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
                let profile = FriendProfile(
                    id: uid,
                    displayName: data["displayName"] as? String ?? "Unknown",
                    photoURL:    (data["photoURL"]   as? String).flatMap(URL.init),
                    todayCompleted: data["todayCompleted"] as? Int ?? 0,
                    todayTotal:     data["todayTotal"]     as? Int ?? 0,
                    streak:         data["streak"]         as? Int ?? 0,
                    lastActiveDate: data["lastActiveDate"] as? String ?? ""
                )
                if let idx = self.friends.firstIndex(where: { $0.id == uid }) {
                    self.friends[idx] = profile
                } else {
                    self.friends.append(profile)
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
                        fromUid: from,
                        fromName:    d["fromName"]    as? String ?? "Unknown",
                        fromPhotoURL:(d["fromPhotoURL"] as? String).flatMap(URL.init),
                        createdAt:  (d["createdAt"]   as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
            }
        mainListeners.append(reg)
    }

    private func listenNotifications(uid: String) {
        let reg = db.collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.notifications = snap?.documents.map { doc -> SocialNotif in
                    let d = doc.data()
                    return SocialNotif(
                        id: doc.documentID,
                        type:     d["type"]     as? String ?? "",
                        fromName: d["fromName"] as? String ?? "",
                        fromPhotoURL: (d["fromPhotoURL"] as? String).flatMap(URL.init),
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        read:      d["read"]     as? Bool   ?? false
                    )
                } ?? []
                self.unreadCount = self.notifications.filter { !$0.read }.count
            }
        mainListeners.append(reg)
    }

    // MARK: - Public stats (called by TaskStore after mutations)

    func updateStats(uid: String, todayCompleted: Int, todayTotal: Int, streak: Int) {
        db.collection("users").document(uid).setData([
            "todayCompleted":  todayCompleted,
            "todayTotal":      todayTotal,
            "streak":          streak,
            "lastActiveDate":  FriendProfile.todayStr()
        ], merge: true)
    }

    // Also writes displayName / email / photoURL so friends can find you
    func writeProfile(uid: String, displayName: String, email: String, photoURL: String?) {
        var data: [String: Any] = [
            "displayName": displayName,
            "email":       email,
        ]
        if let url = photoURL { data["photoURL"] = url }
        db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - Friend requests

    /// Sends a friend request to the user with the given email.
    func sendFriendRequest(toEmail: String, myUid: String, myName: String, myPhotoURL: String?) async {
        isSendingRequest = true
        requestError = nil
        defer { isSendingRequest = false }

        do {
            let snap = try await db.collection("users")
                .whereField("email", isEqualTo: toEmail.lowercased().trimmingCharacters(in: .whitespaces))
                .limit(to: 1)
                .getDocuments()

            guard let targetDoc = snap.documents.first else {
                requestError = "No user found with that email."; return
            }
            let toUid = targetDoc.documentID
            guard toUid != myUid else {
                requestError = "You cannot add yourself."; return
            }

            let alreadyFriend = try await db.collection("users").document(myUid)
                .collection("friends").document(toUid).getDocument()
            if alreadyFriend.exists { requestError = "Already friends!"; return }

            // Check if a request already exists
            let existingReq = try await db.collection("friendRequests")
                .whereField("fromUid", isEqualTo: myUid)
                .whereField("toUid",   isEqualTo: toUid)
                .whereField("status",  isEqualTo: "pending")
                .getDocuments()
            if !(existingReq.documents.isEmpty) { requestError = "Request already sent."; return }

            let reqRef = db.collection("friendRequests").document()
            try await reqRef.setData([
                "fromUid":      myUid,
                "fromName":     myName,
                "fromPhotoURL": myPhotoURL ?? "",
                "toUid":        toUid,
                "toEmail":      toEmail,
                "status":       "pending",
                "createdAt":    Timestamp()
            ])

            // In-app notification for recipient
            try await db.collection("users").document(toUid)
                .collection("notifications").document()
                .setData([
                    "type":         "friend_request",
                    "fromUid":      myUid,
                    "fromName":     myName,
                    "fromPhotoURL": myPhotoURL ?? "",
                    "requestId":    reqRef.documentID,
                    "createdAt":    Timestamp(),
                    "read":         false
                ])
        } catch {
            requestError = error.localizedDescription
        }
    }

    func acceptRequest(_ req: FriendRequest, myUid: String, myName: String, myPhotoURL: String?) async {
        do {
            try await db.collection("friendRequests").document(req.id)
                .setData(["status": "accepted"], merge: true)

            // Mutual friendship docs
            try await db.collection("users").document(myUid)
                .collection("friends").document(req.fromUid)
                .setData(["uid": req.fromUid, "addedAt": Timestamp()])

            try await db.collection("users").document(req.fromUid)
                .collection("friends").document(myUid)
                .setData(["uid": myUid, "addedAt": Timestamp()])

            // Notify requester
            try await db.collection("users").document(req.fromUid)
                .collection("notifications").document()
                .setData([
                    "type":         "accepted",
                    "fromUid":      myUid,
                    "fromName":     myName,
                    "fromPhotoURL": myPhotoURL ?? "",
                    "createdAt":    Timestamp(),
                    "read":         false
                ])
        } catch {}
    }

    func declineRequest(_ req: FriendRequest) {
        db.collection("friendRequests").document(req.id)
            .setData(["status": "declined"], merge: true)
    }

    func removeFriend(friendUid: String, myUid: String) {
        db.collection("users").document(myUid).collection("friends").document(friendUid).delete()
        db.collection("users").document(friendUid).collection("friends").document(myUid).delete()
    }

    // MARK: - Cheer / Nudge

    func sendCheer(to friend: FriendProfile, fromUid: String, fromName: String, fromPhotoURL: String?) {
        db.collection("users").document(friend.id)
            .collection("notifications").document()
            .setData([
                "type":         "cheer",
                "fromUid":      fromUid,
                "fromName":     fromName,
                "fromPhotoURL": fromPhotoURL ?? "",
                "createdAt":    Timestamp(),
                "read":         false
            ])
    }

    func sendNudge(to friend: FriendProfile, fromUid: String, fromName: String, fromPhotoURL: String?) {
        db.collection("users").document(friend.id)
            .collection("notifications").document()
            .setData([
                "type":         "nudge",
                "fromUid":      fromUid,
                "fromName":     fromName,
                "fromPhotoURL": fromPhotoURL ?? "",
                "createdAt":    Timestamp(),
                "read":         false
            ])
    }

    // MARK: - Notifications

    func markAllRead(uid: String) {
        let col = db.collection("users").document(uid).collection("notifications")
        for notif in notifications where !notif.read {
            col.document(notif.id).setData(["read": true], merge: true)
        }
        unreadCount = 0
    }
}
