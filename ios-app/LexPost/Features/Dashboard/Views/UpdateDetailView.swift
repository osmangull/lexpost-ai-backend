import SwiftUI

struct UpdateDetailView: View {
    let update: LegalUpdate
    @State private var showPostEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(update.documentTypeEmoji + " " + update.documentType)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.12))
                            .foregroundColor(typeColor)
                            .clipShape(Capsule())
                        Spacer()
                        Text("Sayı: \(update.gazetteNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(update.title)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(update.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // AI Özet
                if let summary = update.cleanedSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Text("AI Özet")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)

                        Text(summary)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .padding(.horizontal)

                        if let url = URL(string: update.sourceUrl) {
                            Link(destination: url) {
                                Text("Devamını oku →")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Divider()

                // Resmi Gazete linki
                if let url = URL(string: update.sourceUrl) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Resmi Gazete'de Görüntüle")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }

                // Paylaşım görseli oluştur
                Button {
                    showPostEditor = true
                } label: {
                    Label("Paylaşım Görseli Oluştur", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPostEditor) {
            PostEditorView(legalUpdate: update)
        }
    }

    private var typeColor: Color {
        switch update.documentType {
        case "Yönetmelik": return .blue
        case "Tebliğ": return .orange
        case "Karar": return .purple
        default: return .gray
        }
    }
}
