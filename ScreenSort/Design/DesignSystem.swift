//
//  DesignSystem.swift
//  ScreenSort
//
//  Central design system for consistent styling across the app.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // MARK: Colors

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let errorGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Content type colors
    static let musicColor = Color(hex: "EC4899")
    static let movieColor = Color(hex: "8B5CF6")
    static let bookColor = Color(hex: "F59E0B")
    static let memeColor = Color(hex: "10B981")
    static let unknownColor = Color(hex: "6B7280")

    // MARK: Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacing2XL: CGFloat = 48

    // MARK: Corner Radius

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radius2XL: CGFloat = 32

    // MARK: Shadows

    static func cardShadow(color: Color = .black) -> some View {
        Color.clear
            .shadow(color: color.opacity(0.08), radius: 8, y: 4)
            .shadow(color: color.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var tint: Color = .clear
    var padding: CGFloat = AppTheme.spacingMD
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.4),
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        if tint != .clear {
                            RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
                                .fill(tint.opacity(0.08))
                        }
                    }
            }
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

// MARK: - Icon Badge

struct IconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - Animated Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSM) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }

                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
            .shadow(color: Color(hex: "6366F1").opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isLoading)
        .animation(.spring(response: 0.3), value: isLoading)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let text: String
    let color: Color
    let icon: String?

    init(_ text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Animated Progress Ring

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color

    init(progress: Double, lineWidth: CGFloat = 4, color: Color = Color(hex: "6366F1")) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Bounce Animation

extension View {
    func bounceOnTap() -> some View {
        self.modifier(BounceModifier())
    }
}

struct BounceModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}
