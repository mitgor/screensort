//
//  OnboardingView.swift
//  ScreenSort
//
//  Modern onboarding flow with iOS 26 Liquid Glass design.
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var isAnimating = false

    private let pages = OnboardingPage.allPages

    var body: some View {
        ZStack {
            // iOS 26 Liquid Glass background
            backgroundGradient

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, isActive: index == currentPage)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)

                // Bottom controls with glass card
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.top, 24)

                    // Action button with glass effect
                    Button(action: handleButtonTap) {
                        HStack(spacing: 10) {
                            Text(buttonTitle)
                                .fontWeight(.semibold)

                            Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                                .font(.body.weight(.semibold))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .accentColor.opacity(0.3), radius: 12, y: 6)
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: currentPage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background {
                    // Glass footer
                    UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var buttonTitle: String {
        currentPage == pages.count - 1 ? "Get Started" : "Continue"
    }

    private func handleButtonTap() {
        if currentPage < pages.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage: Sendable {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let features: [Feature]

    struct Feature: Sendable {
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
    let isActive: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with symbol effect
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(page.iconColor.gradient)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isActive)
                .shadow(color: page.iconColor.opacity(0.3), radius: 20, y: 10)

            // Title & Subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features with glass cards
            VStack(spacing: 12) {
                ForEach(page.features, id: \.text) { feature in
                    FeatureRow(feature: feature)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: OnboardingPage.Feature

    var body: some View {
        HStack(spacing: 14) {
            // Icon with gradient circle
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }

            Text(feature.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
