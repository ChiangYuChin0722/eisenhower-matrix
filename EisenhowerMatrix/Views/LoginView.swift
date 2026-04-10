import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("appLanguage") private var lang: String = "en"

    @State private var isLoadingApple  = false
    @State private var isLoadingGoogle = false
    @State private var errorMsg: String?
    @State private var showError = false

    private var zh: Bool { lang == "zh" }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer()
                logoSection
                Spacer()
                buttonsSection
                footerText
                Spacer().frame(height: 48)
            }
        }
        .alert(zh ? "登入失敗" : "Sign In Failed",
               isPresented: $showError,
               presenting: errorMsg) { _ in Button("OK") {}
        } message: { msg in Text(msg) }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.blue.opacity(0.06),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: .blue.opacity(0.35), radius: 16, y: 8)

                // 2×2 matrix grid icon
                Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                    GridRow {
                        roundedTile(opacity: 0.55)
                        roundedTile(opacity: 1.0)
                    }
                    GridRow {
                        roundedTile(opacity: 0.35)
                        roundedTile(opacity: 0.70)
                    }
                }
                .frame(width: 44, height: 44)
            }

            VStack(spacing: 8) {
                Text(zh ? "Eisenhower 任務矩陣" : "Eisenhower Matrix")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(zh
                     ? "聰明管理你的時間與任務"
                     : "Work on what matters most")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }

    private func roundedTile(opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(opacity))
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 14) {
            // Sign in with Apple
            SignInWithAppleButton(
                .signIn,
                onRequest:    { authManager.prepareAppleRequest($0) },
                onCompletion: { result in
                    Task {
                        isLoadingApple = true
                        defer { isLoadingApple = false }
                        do    { try await authManager.handleAppleSignIn(result) }
                        catch { showAuthError(error) }
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .cornerRadius(14)
            .overlay {
                if isLoadingApple {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.4))
                    ProgressView().tint(.white)
                }
            }

            // Sign in with Google
            Button {
                Task {
                    isLoadingGoogle = true
                    defer { isLoadingGoogle = false }
                    do    { try await authManager.signInWithGoogle() }
                    catch { showAuthError(error) }
                }
            } label: {
                ZStack {
                    HStack(spacing: 10) {
                        GoogleLogo()
                        Text(zh ? "使用 Google 登入" : "Sign in with Google")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                    if isLoadingGoogle {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(uiColor: .systemBackground).opacity(0.7))
                        ProgressView()
                    }
                }
            }
            .disabled(isLoadingApple || isLoadingGoogle)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }

    // MARK: - Footer

    private var footerText: some View {
        Text(zh
             ? "登入即表示您同意我們的服務條款與隱私政策"
             : "By signing in, you agree to our Terms of Service and Privacy Policy")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func showAuthError(_ error: Error) {
        errorMsg  = error.localizedDescription
        showError = true
    }
}

// MARK: - Google logo (drawn, no image asset required)

struct GoogleLogo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 28, height: 28)

            Text("G")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.92, green: 0.26, blue: 0.21),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
