import SwiftUI

// MARK: - PremiumPaywallView

struct PremiumPaywallView: View {
    var onDismiss: (() -> Void)? = nil

    @StateObject private var premium = PremiumService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentSlide = 0
    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var pricing: PricingInfo? = nil
    @State private var isPurchasing = false

    private let slides: [PaywallSlide] = [
        PaywallSlide(
            icon: "wand.and.stars",
            title: "Görsel İçerik Üreticisi",
            description: "Resmi Gazete yayınlarından saniyeler içinde profesyonel sosyal medya görseli oluşturun."
        ),
        PaywallSlide(
            icon: "photo.on.rectangle.angled",
            title: "Kendi Arkaplanlarınız",
            description: "Markanıza özel görselleri arka plan olarak kullanın. Sınırsız yükleme ve saklama."
        ),
        PaywallSlide(
            icon: "crown.fill",
            title: "Tüm Pro Özellikler",
            description: "Avukatlar ve hukuk profesyonelleri için tasarlanmış eksiksiz araç seti."
        ),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.051, green: 0.106, blue: 0.165).ignoresSafeArea()

            VStack(spacing: 0) {
                // Kapat butonu
                HStack {
                    Spacer()
                    Button {
                        onDismiss?()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // Başlık
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(appNavy)
                            .padding(6)
                            .background(appGold)
                            .clipShape(Circle())
                        Text("LEXPOST PRO")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(appGold)
                            .kerning(2)
                    }
                    Text("Hukuki içeriklerinizi\nprofesyonelleştirin.")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // Slider
                TabView(selection: $currentSlide) {
                    ForEach(slides.indices, id: \.self) { i in
                        SlideCard(slide: slides[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)

                // Dots
                HStack(spacing: 6) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentSlide ? appGold : Color.white.opacity(0.2))
                            .frame(width: i == currentSlide ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: currentSlide)
                    }
                }
                .padding(.top, 16)

                Spacer()

                // Fiyatlandırma
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        PlanCard(
                            title: "Aylık",
                            price: pricing?.monthlyPrice ?? "₺149",
                            subtitle: "her ay",
                            isSelected: selectedPlan == .monthly,
                            badge: nil
                        ) { selectedPlan = .monthly }

                        PlanCard(
                            title: "Yıllık",
                            price: pricing?.yearlyPrice ?? "₺999",
                            subtitle: "yılda bir",
                            isSelected: selectedPlan == .yearly,
                            badge: pricing?.yearlySavings ?? "%44 tasarruf"
                        ) { selectedPlan = .yearly }
                    }
                    .padding(.horizontal, 20)

                    // Satın Al butonu
                    Button {
                        Task {
                            isPurchasing = true
                            _ = await premium.purchasePremium(plan: selectedPlan)
                            isPurchasing = false
                        }
                    } label: {
                        Group {
                            if isPurchasing {
                                HStack(spacing: 8) {
                                    ProgressView().tint(appNavy)
                                    Text("İşleniyor…")
                                }
                            } else {
                                Text("Premium'a Geç")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(appGold)
                        .foregroundColor(appNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: appGold.opacity(0.4), radius: 12, x: 0, y: 5)
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 20)

                    Text("Satın alma yakında aktif olacak.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 12)
                }
            }
        }
        .task { pricing = await premium.fetchPricing() }
    }
}

// MARK: - SlideCard

private struct SlideCard: View {
    let slide: PaywallSlide

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(appGold.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: slide.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(appGold)
            }
            Text(slide.title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.white)
            Text(slide.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PlanCard

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(appNavy)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(appGold)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 20)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                Text(price)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(isSelected ? appGold : .white.opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.07, green: 0.13, blue: 0.19))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? appGold : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - PremiumUpgradeDialog

struct PremiumUpgradeDialog: View {
    let featureTitle: String
    let featureDescription: String
    @Binding var isPresented: Bool
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color(red: 0.051, green: 0.106, blue: 0.165).ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                ZStack {
                    Circle().fill(appGold.opacity(0.12)).frame(width: 64, height: 64)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(appGold)
                }

                VStack(spacing: 8) {
                    Text("Premium Özellik")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(appGold)
                        .kerning(1.5)
                    Text(featureTitle)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Text(featureDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }

                Button {
                    showPaywall = true
                } label: {
                    Text("Premium'a Geç")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(appGold)
                        .foregroundColor(appNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: appGold.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 20)

                Button("Şimdi Değil") { isPresented = false }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showPaywall) {
            PremiumPaywallView { isPresented = false }
        }
    }
}

// MARK: - Model

private struct PaywallSlide {
    let icon: String
    let title: String
    let description: String
}
