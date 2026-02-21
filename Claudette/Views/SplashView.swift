import SwiftUI
import UIKit

struct SplashView: View {
    let config: AppConfiguration
    let onFinished: () -> Void

    @State private var showLogo = false
    @State private var showTextAnimation = false
    @State private var showSlogan = false
    @State private var fadeOut = false

    private var accentColor: Color {
        Color(UIColor(hex: config.splashAccentColor))
    }

    private var accentColorLight: Color {
        Color(UIColor(hex: config.splashAccentColorLight))
    }

    private var accentColorDark: Color {
        Color(UIColor(hex: config.splashAccentColorDark))
    }

    private var backgroundColor: Color {
        Color(UIColor(hex: config.splashBackgroundColor))
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            RadialGradient(
                colors: [accentColorDark.opacity(0.15), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                logoSection
                    .scaleEffect(showLogo ? 1.0 : 0.85)
                    .opacity(showLogo ? 1 : 0)

                if showSlogan {
                    sloganSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                footerSection
                    .opacity(showLogo ? 1 : 0)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .opacity(fadeOut ? 0 : 1)
        .onTapGesture { skipSplash() }
        .task { await startSplash() }
    }

    // MARK: - Logo

    private var nameOffset: CGFloat {
        showTextAnimation ? 0 : -300
    }

    private var cursorOffset: CGFloat {
        showTextAnimation ? 0 : 300
    }

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                accentColorDark.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                Text("C>")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColorLight, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 120, height: 120)
            .shadow(color: accentColor.opacity(0.25), radius: 20)

            HStack(spacing: 0) {
                Text(config.splashAppName)
                    .foregroundColor(.white)
                    .font(.system(size: 36, weight: .bold))
                    .offset(x: nameOffset)

                Text(config.splashCursorSymbol)
                    .foregroundColor(accentColor)
                    .font(.system(size: 36, weight: .bold))
                    .offset(x: cursorOffset)
            }
        }
    }

    // MARK: - Slogan

    private var sloganSection: some View {
        Text(config.splashSlogan)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [accentColorLight, accentColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .multilineTextAlignment(.center)
    }

    // MARK: - Footer

    private var footerSection: some View {
        footerAttributedText
            .font(.system(size: 12))
    }

    private var footerAttributedText: Text {
        let footer = config.splashFooterText
        let suffix = ".ai"
        if footer.hasSuffix(suffix),
           let range = footer.range(of: suffix, options: .backwards)
        {
            let prefix = String(footer[footer.startIndex ..< range.lowerBound])
            return Text(prefix)
                .foregroundColor(.white.opacity(0.5))
                + Text(suffix)
                .foregroundColor(accentColorDark)
        }
        return Text(footer)
            .foregroundColor(.white.opacity(0.5))
    }

    // MARK: - Animation

    private func startSplash() async {
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeOut(duration: 0.8)) {
            showLogo = true
        }

        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.easeInOut(duration: 0.6)) {
            showTextAnimation = true
        }

        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeInOut(duration: 0.6)) {
            showSlogan = true
        }

        try? await Task.sleep(for: .seconds(3.0))
        withAnimation(.easeInOut(duration: 0.5)) {
            fadeOut = true
        }

        try? await Task.sleep(for: .seconds(0.5))
        onFinished()
    }

    private func skipSplash() {
        guard !fadeOut else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            fadeOut = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            onFinished()
        }
    }
}
