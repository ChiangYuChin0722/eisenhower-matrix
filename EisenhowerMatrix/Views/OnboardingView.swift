import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appLanguage")       private var lang: String = "en"
    @AppStorage("appAccent")         private var appAccent: String = "blue"
    @State private var currentPage = 0

    private var s: Str { Str(lang) }
    private var accent: Color { .accent(appAccent) }
    private let totalPages = 4

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            // Skip button
            HStack {
                Spacer()
                Button(s.skip) {
                    HapticManager.shared.impact(.light)
                    hasSeenOnboarding = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .opacity(currentPage < totalPages - 1 ? 1 : 0)
            .zIndex(1)

            // Pages
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    quadrantPage.tag(1)
                    featuresPage.tag(2)
                    startPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Dot indicator + button
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? accent : Color.secondary.opacity(0.3))
                                .frame(width: i == currentPage ? 20 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: currentPage)
                        }
                    }

                    Button {
                        HapticManager.shared.impact(.medium)
                        if currentPage < totalPages - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                        } else {
                            hasSeenOnboarding = true
                        }
                    } label: {
                        Text(currentPage == totalPages - 1 ? s.getStarted : s.next)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accent)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 64))
                    .foregroundColor(accent)
            }
            VStack(spacing: 12) {
                Text(s.onboardWelcomeTitle)
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(s.onboardWelcomeSub)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: The 4 Quadrants

    private var quadrantPage: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    quadrantCell(.schedule)
                    quadrantCell(.doFirst)
                }
                HStack(spacing: 3) {
                    quadrantCell(.eliminate)
                    quadrantCell(.delegate)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 28)

            VStack(spacing: 10) {
                Text(s.onboardMatrixTitle)
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(s.onboardMatrixSub)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }

    private func quadrantCell(_ q: Quadrant) -> some View {
        let color = q.color(theme: "classic")
        return VStack(spacing: 6) {
            Circle().fill(color).frame(width: 16, height: 16)
            Text(s.quadrantTitle(q))
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
            Text(s.quadrantSubtitle(q))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(12)
        .background(color.opacity(0.08))
    }

    // MARK: - Page 3: Features

    private var featuresPage: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                Text(s.onboardFeatTitle)
                    .font(.title2).fontWeight(.bold)
                    .padding(.bottom, 8)
                featureRow("calendar",                    color: .blue,   title: s.tabCalendar,  desc: s.onboardFeatureCalendar)
                featureRow("clock.badge.exclamationmark", color: .orange, title: s.tabDeadlines, desc: s.onboardFeatureDeadlines)
                featureRow("checklist",                   color: .green,  title: s.tabChecklist, desc: s.onboardFeatureChecklist)
                featureRow("chart.bar.fill",              color: .purple, title: s.tabDashboard, desc: s.onboardFeatureDashboard)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private func featureRow(_ icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Page 4: Get Started

    private var startPage: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            VStack(spacing: 12) {
                Text(s.onboardStartTitle)
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(s.onboardStartSub)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
