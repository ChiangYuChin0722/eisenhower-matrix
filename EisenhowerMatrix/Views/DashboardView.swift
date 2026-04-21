import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var taskStore:    TaskStore
    @EnvironmentObject var authManager:  AuthManager
    @EnvironmentObject var friendMgr:    FriendManager
    @AppStorage("appLanguage") private var lang:       String = "en"
    @AppStorage("appAccent")   private var appAccent:  String = "blue"
    @AppStorage("matrixTheme") private var matrixTheme: String = "classic"

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }
    private func qColor(_ q: Quadrant) -> Color { q.color(theme: matrixTheme) }

    @State private var showAddFriend    = false
    @State private var addFriendEmail   = ""
    @State private var cheerSent        = Set<String>()    // friend UIDs that got a cheer this session
    @State private var nudgeSent        = Set<String>()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    myStatsCard
                    friendsSection
                    if !friendMgr.incomingRequests.isEmpty { requestsSection }
                    if !friendMgr.notifications.isEmpty    { notificationsSection }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color.appBackground)
            .navigationTitle(lang == "zh" ? "好友" : "Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddFriend = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) { addFriendSheet }
            .onAppear {
                if let uid = authManager.user?.uid {
                    friendMgr.markAllRead(uid: uid)
                }
            }
        }
    }

    // MARK: - My Stats

    private var myStatsCard: some View {
        HStack(spacing: 16) {
            // Streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(taskStore.currentStreak > 0 ? "🔥" : "💤")
                        .font(.title2)
                    Text("\(taskStore.currentStreak)")
                        .font(.title2).fontWeight(.bold)
                }
                Text(lang == "zh" ? "連續天數" : "Day streak")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44)

            // Today
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(taskStore.todayCompletedCount)")
                        .font(.title2).fontWeight(.bold).foregroundColor(accent)
                    Text("/ \(taskStore.totalCount)")
                        .font(.title2).foregroundColor(.secondary)
                }
                Text(lang == "zh" ? "今日完成" : "Done today")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44)

            // Avatar
            VStack(spacing: 4) {
                authManager.avatarView(size: 36)
                Text(authManager.user?.displayName?.components(separatedBy: " ").first ?? "Me")
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Friends

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lang == "zh" ? "好友" : "Friends")
                    .font(.headline)
                Spacer()
                Button {
                    showAddFriend = true
                } label: {
                    Label(lang == "zh" ? "新增" : "Add", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundColor(accent)
                }
            }

            if friendMgr.friends.isEmpty {
                emptyFriendsState
            } else {
                ForEach(friendMgr.friends) { friend in
                    friendCard(friend)
                }
            }
        }
    }

    private var emptyFriendsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text(lang == "zh" ? "還沒有好友" : "No friends yet")
                .font(.subheadline).fontWeight(.medium)
            Text(lang == "zh"
                 ? "輸入朋友的 email 來邀請他們互相督促！"
                 : "Add friends by email to keep each other accountable!")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddFriend = true
            } label: {
                Label(lang == "zh" ? "新增好友" : "Add a Friend", systemImage: "person.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }

    private func friendCard(_ friend: FriendProfile) -> some View {
        let alreadyCheered = cheerSent.contains(friend.id)
        let alreadyNudged  = nudgeSent.contains(friend.id)

        return VStack(alignment: .leading, spacing: 10) {
            // Top row: avatar + name + streak + active badge
            HStack(spacing: 10) {
                avatarView(url: friend.photoURL, name: friend.displayName, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 6) {
                        if friend.streak > 0 {
                            Label("\(friend.streak)", systemImage: "flame.fill")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        if friend.isActiveToday {
                            Text(lang == "zh" ? "今天有在做" : "Active today")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                // Context menu to remove friend
                Menu {
                    Button(role: .destructive) {
                        if let myUid = authManager.user?.uid {
                            friendMgr.removeFriend(friendUid: friend.id, myUid: myUid)
                        }
                    } label: {
                        Label(lang == "zh" ? "移除好友" : "Remove Friend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(.secondary)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lang == "zh"
                         ? "今日完成 \(friend.todayCompleted)/\(friend.todayTotal)"
                         : "\(friend.todayCompleted)/\(friend.todayTotal) done today")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(friend.todayProgress * 100))%")
                        .font(.caption).fontWeight(.semibold).foregroundColor(accent)
                }
                ProgressView(value: friend.todayProgress)
                    .tint(friend.todayProgress >= 1.0 ? .green : accent)
            }

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    guard !alreadyCheered,
                          let myUid  = authManager.user?.uid,
                          let myName = authManager.user?.displayName
                    else { return }
                    cheerSent.insert(friend.id)
                    friendMgr.sendCheer(
                        to: friend, fromUid: myUid, fromName: myName,
                        fromPhotoURL: authManager.user?.photoURL?.absoluteString
                    )
                } label: {
                    Label(alreadyCheered
                          ? (lang == "zh" ? "已加油" : "Cheered!")
                          : (lang == "zh" ? "加油" : "Cheer"),
                          systemImage: alreadyCheered ? "checkmark" : "flame")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(alreadyCheered ? .green : .orange)
                .disabled(alreadyCheered)

                Button {
                    guard !alreadyNudged && !friend.isActiveToday,
                          let myUid  = authManager.user?.uid,
                          let myName = authManager.user?.displayName
                    else { return }
                    nudgeSent.insert(friend.id)
                    friendMgr.sendNudge(
                        to: friend, fromUid: myUid, fromName: myName,
                        fromPhotoURL: authManager.user?.photoURL?.absoluteString
                    )
                } label: {
                    Label(alreadyNudged
                          ? (lang == "zh" ? "已催了" : "Nudged!")
                          : (lang == "zh" ? "催一下" : "Nudge"),
                          systemImage: alreadyNudged ? "checkmark" : "hand.wave")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(alreadyNudged ? .green : .blue)
                .disabled(alreadyNudged || friend.isActiveToday)
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang == "zh" ? "好友邀請" : "Friend Requests")
                .font(.headline)

            ForEach(friendMgr.incomingRequests) { req in
                HStack(spacing: 12) {
                    avatarView(url: req.fromPhotoURL, name: req.fromName, size: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(req.fromName).font(.subheadline).fontWeight(.medium)
                        Text(lang == "zh" ? "想加你為好友" : "wants to be friends")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            Task {
                                if let myUid  = authManager.user?.uid,
                                   let myName = authManager.user?.displayName {
                                    await friendMgr.acceptRequest(
                                        req, myUid: myUid, myName: myName,
                                        myPhotoURL: authManager.user?.photoURL?.absoluteString
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            friendMgr.declineRequest(req)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lang == "zh" ? "最新動態" : "Activity")
                    .font(.headline)
                if friendMgr.unreadCount > 0 {
                    Text("\(friendMgr.unreadCount)")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accent)
                        .cornerRadius(8)
                }
            }

            VStack(spacing: 0) {
                ForEach(friendMgr.notifications.prefix(10)) { notif in
                    HStack(spacing: 12) {
                        Text(notif.emoji).font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(notif.message)
                                .font(.subheadline)
                                .foregroundColor(notif.read ? .secondary : .primary)
                            Text(notif.createdAt, style: .relative)
                                .font(.caption2).foregroundColor(.secondary)
                        }

                        Spacer()

                        if !notif.read {
                            Circle().fill(accent).frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(notif.read ? Color.clear : accent.opacity(0.04))

                    if notif.id != friendMgr.notifications.prefix(10).last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
    }

    // MARK: - Add Friend Sheet

    private var addFriendSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(accent)
                    Text(lang == "zh" ? "新增好友" : "Add a Friend")
                        .font(.title2).fontWeight(.bold)
                    Text(lang == "zh"
                         ? "輸入朋友的帳號 email，他們需要先在 app 登入過"
                         : "Enter their account email. They must have signed into the app before.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 0) {
                    TextField(lang == "zh" ? "朋友的 email" : "Friend's email", text: $addFriendEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                if let err = friendMgr.requestError {
                    Text(err).font(.subheadline).foregroundColor(.red)
                }

                Button {
                    Task {
                        guard let myUid  = authManager.user?.uid,
                              let myName = authManager.user?.displayName ?? authManager.user?.email
                        else { return }
                        await friendMgr.sendFriendRequest(
                            toEmail: addFriendEmail,
                            myUid:   myUid,
                            myName:  myName,
                            myPhotoURL: authManager.user?.photoURL?.absoluteString
                        )
                        if friendMgr.requestError == nil {
                            addFriendEmail = ""
                            showAddFriend  = false
                        }
                    }
                } label: {
                    Group {
                        if friendMgr.isSendingRequest {
                            ProgressView()
                        } else {
                            Text(lang == "zh" ? "送出邀請" : "Send Request")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .disabled(addFriendEmail.trimmingCharacters(in: .whitespaces).isEmpty || friendMgr.isSendingRequest)

                Spacer()
            }
            .padding(.top, 32)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang == "zh" ? "取消" : "Cancel") {
                        addFriendEmail = ""
                        friendMgr.requestError = nil
                        showAddFriend = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func avatarView(url: URL?, name: String, size: CGFloat) -> some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: size, height: size).clipShape(Circle())
                    default:
                        initialsCircle(name: name, size: size)
                    }
                }
            } else {
                initialsCircle(name: name, size: size)
            }
        }
    }

    private func initialsCircle(name: String, size: CGFloat) -> some View {
        let initials = name.components(separatedBy: " ")
            .prefix(2).compactMap { $0.first }.map(String.init).joined()
        return ZStack {
            Circle().fill(accent.opacity(0.2))
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(accent)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    DashboardView()
        .environmentObject(TaskStore())
        .environmentObject(AuthManager())
        .environmentObject(FriendManager.shared)
}
