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

    private let pages = OnboardingPage.allPages

    var body: some View {
        ZStack {
            // Animated background
            AnimatedOnboardingBackground(currentPage: currentPage)

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

                // Bottom controls with glass effect
                VStack(spacing: AppTheme.spacingLG) {
                    // Page indicators
                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color(hex: "6366F1") : Color.secondary.opacity(0.3))
                                .frame(width: index == currentPage ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action button
                    Button(action: handleButtonTap) {
                        HStack(spacing: AppTheme.spacingSM) {
                            Text(buttonTitle)
                                .fontWeight(.semibold)

                            Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                                .font(.body.weight(.semibold))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
                        .shadow(color: Color(hex: "6366F1").opacity(0.4), radius: 16, y: 8)
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: currentPage)
                    .bounceOnTap()
                    .padding(.horizontal, AppTheme.spacingLG)
                }
                .padding(.top, AppTheme.spacingLG)
                .padding(.bottom, AppTheme.spacing2XL)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: AppTheme.radius2XL, topTrailingRadius: AppTheme.radius2XL)
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
            }
        }
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

// MARK: - Animated Background

struct AnimatedOnboardingBackground: View {
    let currentPage: Int
    @State private var animate = false

    private let pageColors: [Color] = [
        Color(hex: "6366F1"),  // Blue/Purple for welcome
        Color(hex: "10B981"),  // Green for photos
        Color(hex: "EF4444"),  // Red for Google
        Color(hex: "8B5CF6")   // Purple for ready
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)

            // Animated gradient orbs
            Circle()
                .fill(pageColors[currentPage].opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animate ? 100 : -100, y: animate ? -150 : -100)

            Circle()
                .fill(pageColors[(currentPage + 1) % pageColors.count].opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -80 : 80, y: animate ? 300 : 250)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: currentPage)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
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
        OnboardingPage(
            icon: "rectangle.stack.fill",
            iconColor: Color(hex: "6366F1"),
            title: "Welcome to ScreenSort",
            subtitle: "Automatically organize your screenshots by content type",
            features: [
                Feature(icon: "music.note", text: "Music screenshots to YouTube playlists"),
                Feature(icon: "film", text: "Movies linked to TMDb"),
                Feature(icon: "book", text: "Books found on Google Books"),
                Feature(icon: "face.smiling", text: "Memes sorted to their own album")
            ]
        ),
        OnboardingPage(
            icon: "photo.on.rectangle.angled",
            iconColor: Color(hex: "10B981"),
            title: "Access Your Screenshots",
            subtitle: "ScreenSort needs access to your photo library to find and organize screenshots",
            features: [
                Feature(icon: "magnifyingglass", text: "Scan screenshots for content"),
                Feature(icon: "folder", text: "Create organized albums"),
                Feature(icon: "text.viewfinder", text: "Read text using on-device AI"),
                Feature(icon: "lock.shield", text: "All processing stays on your device")
            ]
        ),
        OnboardingPage(
            icon: "link.circle.fill",
            iconColor: Color(hex: "EF4444"),
            title: "Connect Your Accounts",
            subtitle: "Sign in with Google to unlock powerful integrations",
            features: [
                Feature(icon: "play.rectangle", text: "Add songs to YouTube playlists"),
                Feature(icon: "doc.text", text: "Log everything to Google Docs"),
                Feature(icon: "books.vertical", text: "Find books on Google Books"),
                Feature(icon: "hand.raised", text: "You control what gets shared")
            ]
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: Color(hex: "8B5CF6"),
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
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            // Icon with glow effect
            ZStack {
                // Glow
                Circle()
                    .fill(page.iconColor.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.iconColor, page.iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating.speed(0.5), isActive: isActive)
            }

            // Title & Subtitle
            VStack(spacing: AppTheme.spacingSM) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingXL)
            }

            // Features
            VStack(spacing: AppTheme.spacingSM) {
                ForEach(page.features, id: \.text) { feature in
                    OnboardingFeatureRow(feature: feature, accentColor: page.iconColor)
                }
            }
            .padding(.horizontal, AppTheme.spacingLG)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Feature Row

struct OnboardingFeatureRow: View {
    let feature: OnboardingPage.Feature
    let accentColor: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accentColor)
                }

            Text(feature.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingSM)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
