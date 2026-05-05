import SwiftUI

// MARK: - Data

private struct OnboardingPage {
    let icon: String
    let isEmoji: Bool
    let title: String
    let body: String
    let accentPhrase: String
    var isPremium: Bool = false
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "⚖️",
        isEmoji: true,
        title: "LexPost AI",
        body: "Türk hukuku için akıllı gazete takibi",
        accentPhrase: "akıllı gazete takibi"
    ),
    OnboardingPage(
        icon: "newspaper.fill",
        isEmoji: false,
        title: "Günlük Resmi Gazete",
        body: "Her gün yayınlanan Yönetmelik, Tebliğ ve Kararları otomatik olarak takip edin.",
        accentPhrase: "otomatik olarak"
    ),
    OnboardingPage(
        icon: "text.bubble.fill",
        isEmoji: false,
        title: "Yapay Zeka Özetleri",
        body: "Her güncelleme için Groq AI ile hazırlanmış hukuki özetler anında elinizde.",
        accentPhrase: "Groq AI"
    ),
    OnboardingPage(
        icon: "wand.and.stars",
        isEmoji: false,
        title: "Görsel İçerik Oluşturucu",
        body: "Resmi Gazete yayınlarından profesyonel sosyal medya görseli saniyeler içinde oluşturun.",
        accentPhrase: "saniyeler içinde",
        isPremium: true
    ),
    OnboardingPage(
        icon: "photo.on.rectangle.angled",
        isEmoji: false,
        title: "Kendi Görselleriniz",
        body: "Markanıza özel arka plan görselleri kullanarak içeriklerinizi kişiselleştirin.",
        accentPhrase: "kişiselleştirin",
        isPremium: true
    ),
]

// MARK: - Main View

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 24
    @State private var titleOpacity: Double = 0
    @State private var bodyOffset: CGFloat = 16
    @State private var bodyOpacity: Double = 0

    private let navy   = Color(red: 0.051, green: 0.106, blue: 0.165)  // #0D1B2A
    private let gold   = Color(red: 0.831, green: 0.686, blue: 0.216)  // #D4AF37
    private let gold2  = Color(red: 0.918, green: 0.796, blue: 0.400)  // lighter gold
    private let isLast: Bool  // computed below

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self.isLast = false // placeholder — will use computed
    }

    var body: some View {
        ZStack {
            // Background
            navy.ignoresSafeArea()
            backgroundDecor

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Atla") { onComplete() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(gold.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .frame(height: 52)
                .padding(.top, 8)

                Spacer()

                // Page content — driven by TabView for swipe
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        PageSlide(page: page, index: index, gold: gold, gold2: gold2)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentPage)
                .frame(maxHeight: .infinity)

                // Page dots + CTA
                VStack(spacing: 32) {
                    pageDots

                    if currentPage == pages.count - 1 {
                        startButton
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        nextButton
                            .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentPage)
                .padding(.bottom, 52)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Background decoration

    private var backgroundDecor: some View {
        ZStack {
            // Top-right orb
            Circle()
                .fill(gold.opacity(0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: 130, y: -200)

            // Bottom-left orb
            Circle()
                .fill(gold.opacity(0.04))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: -120, y: 280)

            // Subtle grid lines
            GeometryReader { geo in
                let cols = 6
                let spacing = geo.size.width / CGFloat(cols)
                ForEach(0..<cols, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.025))
                        .frame(width: 0.5)
                        .offset(x: spacing * CGFloat(i))
                }
            }
            .ignoresSafeArea()

            // Top thin gold line
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [gold.opacity(0), gold.opacity(0.5), gold.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.top, 1)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? gold : Color.white.opacity(0.25))
                    .frame(width: i == currentPage ? 24 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    // MARK: - Buttons

    private var nextButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                currentPage += 1
            }
        } label: {
            HStack(spacing: 8) {
                Text("İleri")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(navy)
            .frame(width: 160, height: 52)
            .background(gold)
            .clipShape(Capsule())
            .shadow(color: gold.opacity(0.35), radius: 16, x: 0, y: 6)
        }
    }

    private var startButton: some View {
        Button(action: onComplete) {
            HStack(spacing: 10) {
                Text("Başla")
                    .font(.system(size: 17, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(navy)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [gold, gold2],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: gold.opacity(0.4), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Page Slide

private struct PageSlide: View {
    let page: OnboardingPage
    let index: Int
    let gold: Color
    let gold2: Color

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack(alignment: .topTrailing) {
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(gold.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .scaleEffect(appeared ? 1 : 0.5)

                    Circle()
                        .stroke(gold.opacity(0.18), lineWidth: 1)
                        .frame(width: 140, height: 140)
                        .scaleEffect(appeared ? 1 : 0.6)

                    if page.isEmoji {
                        Text(page.icon)
                            .font(.system(size: 72))
                            .scaleEffect(appeared ? 1 : 0.5)
                            .opacity(appeared ? 1 : 0)
                    } else {
                        Image(systemName: page.icon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [gold, gold2],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(appeared ? 1 : 0.5)
                            .opacity(appeared ? 1 : 0)
                    }
                }
                .frame(width: 160, height: 160)

                // Premium crown badge
                if page.isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(1)
                    }
                    .foregroundColor(Color(red: 0.051, green: 0.106, blue: 0.165))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(gold)
                    .clipShape(Capsule())
                    .shadow(color: gold.opacity(0.4), radius: 6, x: 0, y: 2)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: 8, y: -4)
                }
            }
            .padding(.bottom, 48)

            // Title
            Text(page.title)
                .font(.system(size: index == 0 ? 36 : 28, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 20)

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [gold.opacity(0), gold.opacity(0.6), gold.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: appeared ? 80 : 0, height: 1)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                .padding(.bottom, 24)

            // Body
            if index == 0 {
                Text(page.body)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(gold.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .padding(.horizontal, 40)
            } else {
                highlightedBody(page.body, accent: page.accentPhrase)
                    .multilineTextAlignment(.center)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }

    private func highlightedBody(_ text: String, accent: String) -> Text {
        guard let range = text.range(of: accent) else {
            return Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.white.opacity(0.65))
        }
        let before = String(text[text.startIndex..<range.lowerBound])
        let after  = String(text[range.upperBound...])
        return Text(before)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(Color.white.opacity(0.65))
        + Text(accent)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(gold)
        + Text(after)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(Color.white.opacity(0.65))
    }
}
