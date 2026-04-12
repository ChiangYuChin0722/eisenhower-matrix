import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("appLanguage") private var lang = "en"
    @Environment(\.dismiss) private var dismiss

    @State private var displayName    = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var localImage: UIImage? = nil
    @State private var isSaving       = false
    @State private var showSuccess    = false

    private var zh: Bool { lang == "zh" }

    var body: some View {
        Form {
            // MARK: Avatar
            Section {
                HStack {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        avatarCircle
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                                .background(
                                    Circle()
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(width: 26, height: 26)
                                )
                        }
                        .offset(x: 4, y: 4)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // MARK: Display name
            Section(zh ? "顯示名稱" : "Display Name") {
                TextField(zh ? "請輸入名稱" : "Enter name", text: $displayName)
                    .autocorrectionDisabled()
            }

            // MARK: Email (read-only)
            Section(zh ? "電子郵件" : "Email") {
                Text(authManager.user?.email ?? "—")
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(zh ? "編輯個人檔案" : "Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(zh ? "儲存" : "Save") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .alert(zh ? "儲存成功" : "Saved", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        }
        .onAppear { loadCurrent() }
        .onChange(of: selectedItem) { newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let img  = UIImage(data: data)
                else { return }
                localImage = img
                // Compress to JPEG and store locally
                if let jpeg = img.jpegData(compressionQuality: 0.85) {
                    AuthManager.saveLocalAvatar(jpeg)
                }
            }
        }
    }

    // MARK: - Avatar display

    private var avatarCircle: some View {
        Group {
            if let img = localImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else if let img = AuthManager.loadLocalAvatar() {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else if let url = authManager.user?.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholderPerson
                    }
                }
            } else {
                placeholderPerson
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
    }

    private var placeholderPerson: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 90))
            .foregroundColor(.secondary)
    }

    // MARK: - Helpers

    private func loadCurrent() {
        displayName = authManager.user?.displayName ?? ""
        localImage  = AuthManager.loadLocalAvatar()
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        await authManager.updateProfile(displayName: displayName)
        showSuccess = true
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
            .environmentObject(AuthManager())
    }
}
