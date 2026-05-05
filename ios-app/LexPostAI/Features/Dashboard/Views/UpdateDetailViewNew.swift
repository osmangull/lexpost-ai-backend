import SwiftUI

struct UpdateDetailViewNew: View {
    let update: LegalUpdate
    @State private var showPostEditor = false
    @Environment(\.colorScheme) private var scheme

    private var bg: Color      { scheme == .dark ? appNavy     : Color(.systemBackground) }
    private var cardBg: Color  { scheme == .dark ? appCardDark : Color(.secondarySystemBackground) }
    private var primary: Color { scheme == .dark ? .white.opacity(0.92) : Color(.label) }
    private var secondary: Color { scheme == .dark ? .white.opacity(0.55) : Color(.secondaryLabel) }
    private var border: Color  { scheme == .dark ? .white.opacity(0.07)  : Color(.systemGray5) }

    private var typeColor: Color { appDocColor(update.documentType) }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                    mainContent
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarColorScheme(scheme == .dark ? .dark : .light, for: .navigationBar)
        .sheet(isPresented: $showPostEditor) {
            PostEditorView(legalUpdate: update)
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [typeColor.opacity(scheme == .dark ? 0.18 : 0.10), bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)

            Circle()
                .fill(typeColor.opacity(0.07))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: 120, y: -40)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(update.documentType.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(typeColor)
                        .kerning(1.5)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(typeColor.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(typeColor.opacity(0.3), lineWidth: 0.5))

                    Text("Sayı: \(update.gazetteNumber)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(secondary.opacity(0.6))
                }

                Text(update.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: "calendar").font(.system(size: 11)).foregroundColor(appGold.opacity(0.7))
                    Text(update.formattedDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(appGold.opacity(0.85))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Divider
            Rectangle()
                .fill(LinearGradient(
                    colors: [appGold.opacity(0), appGold.opacity(0.35), appGold.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // AI Özet
            if let summary = update.cleanedSummary {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold)).foregroundColor(appGold)
                        Text("AI Özet").font(.system(size: 13, weight: .semibold)).foregroundColor(appGold)
                        Spacer()
                        Text("Groq AI")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(secondary.opacity(0.5))
                            .kerning(0.5)
                    }
                    Rectangle().fill(appGold.opacity(0.15)).frame(height: 1)
                    Text(summary)
                        .font(.system(size: 15))
                        .foregroundColor(primary.opacity(scheme == .dark ? 1 : 0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: update.sourceUrl) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text("Devamını oku").font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(appGold)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(18)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
                .padding(.horizontal, 16)
            }

            // Resmi Gazete
            if let url = URL(string: update.sourceUrl) {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(.systemGray5)).frame(width: 38, height: 38)
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resmi Gazete'de Görüntüle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(primary)
                            Text("resmigazete.gov.tr")
                                .font(.system(size: 11))
                                .foregroundColor(secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(secondary.opacity(0.5))
                    }
                    .padding(14)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
                }
                .padding(.horizontal, 16)
            }

            // CTA
            Button { showPostEditor = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 16, weight: .semibold))
                    Text("Paylaşım Görseli Oluştur").font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(appNavy)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(appGold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: appGold.opacity(0.35), radius: 12, x: 0, y: 5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 36)
        }
        .padding(.top, 20)
    }
}
