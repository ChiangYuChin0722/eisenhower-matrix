import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - AppDelegate (needed for Google Sign-In URL handling)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - App

@main
struct EisenhowerMatrixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var taskStore   = TaskStore()
    @StateObject private var authManager = AuthManager()
    @StateObject private var friendMgr   = FriendManager.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    // Brief splash while Firebase checks cached auth
                    SplashView()
                } else if authManager.isSignedIn {
                    ContentView()
                        .environmentObject(taskStore)
                        .environmentObject(authManager)
                        .environmentObject(friendMgr)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: authManager.isSignedIn)
            .animation(.easeInOut(duration: 0.25), value: authManager.isLoading)
        }
    }
}

// MARK: - Splash (shown for ~0.3s while Firebase resolves cached user)

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }
                ProgressView()
                    .padding(.top, 4)
            }
        }
    }
}
