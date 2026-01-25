//
//  OnboardingView.swift
//  ScreenSort
//
//  Modern onboarding flow explaining app functionality and permissions.
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages = OnboardingPage.allPages

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom controls
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.top, 20)

                    // Action button
                    Button(action: handleButtonTap) {
                        Text(buttonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var buttonTitle: String {
        if currentPage == pages.count - 1 {
            return "Get Started"
        } else {
            return "Continue"
        }
    }

    private func handleButtonTap() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            // Complete onboarding
            withAnimation {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [Feature]

    struct Feature {
        let icon: String
        let text: String
    }

    static let allPages: [OnboardingPage] = [
        // Page 1: Welcome
        OnboardingPage(
            icon: "rectangle.stack.fill",
            iconColor: .blue,
            title: "Welcome to ScreenSort",
            subtitle: "Automatically organize your screenshots by content type",
            features: [
                Feature(icon: "music.note", text: "Music screenshots to YouTube playlists"),
                Feature(icon: "film", text: "Movies linked to TMDb"),
                Feature(icon: "book", text: "Books found on Google Books"),
                Feature(icon: "face.smiling", text: "Memes sorted to their own album")
            ]
        ),

        // Page 2: Photos Permission
        OnboardingPage(
            icon: "photo.on.rectangle.angled",
            iconColor: .green,
            title: "Access Your Screenshots",
            subtitle: "ScreenSort needs access to your photo library to find and organize screenshots",
            features: [
                Feature(icon: "magnifyingglass", text: "Scan screenshots for content"),
                Feature(icon: "folder", text: "Create organized albums"),
                Feature(icon: "text.viewfinder", text: "Read text using on-device AI"),
                Feature(icon: "lock.shield", text: "All processing stays on your device")
            ]
        ),

        // Page 3: Google Permission
        OnboardingPage(
            icon: "link.circle.fill",
            iconColor: .red,
            title: "Connect Your Accounts",
            subtitle: "Sign in with Google to unlock powerful integrations",
            features: [
                Feature(icon: "play.rectangle", text: "Add songs to YouTube playlists"),
                Feature(icon: "doc.text", text: "Log everything to Google Docs"),
                Feature(icon: "books.vertical", text: "Find books on Google Books"),
                Feature(icon: "hand.raised", text: "You control what gets shared")
            ]
        ),

        // Page 4: Ready
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .accentColor,
            title: "You're All Set",
            subtitle: "Grant permissions on the next screen and start sorting",
            features: [
                Feature(icon: "1.circle", text: "Allow photo library access"),
                Feature(icon: "2.circle", text: "Sign in with Google"),
                Feature(icon: "3.circle", text: "Tap Process Now"),
                Feature(icon: "sparkles", text: "Watch the magic happen")
            ]
        )
    ]
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(page.iconColor)
                .symbolRenderingMode(.hierarchical)

            // Title & Subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.features, id: \.text) { feature in
                    HStack(spacing: 16) {
                        Image(systemName: feature.icon)
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .frame(width: 28)

                        Text(feature.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
