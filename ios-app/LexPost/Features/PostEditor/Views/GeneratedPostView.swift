import SwiftUI
import UIKit
import Photos

struct GeneratedPostView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var saveToast: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .shadow(radius: 12, x: 0, y: 4)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 12) {
                    Button { saveToPhotos() } label: {
                        Label("Galeriye Kaydet", systemImage: "square.and.arrow.down")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button("Kapat", action: onDismiss)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .bottom) {
            if let msg = saveToast {
                Text(msg)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: saveToast)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
    }

    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    showToast("Galeri iznine ihtiyaç var. Ayarlar'dan izin verin.")
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                showToast("Görsel galeriye kaydedildi.")
            }
        }
    }

    private func showToast(_ message: String) {
        saveToast = message
        Task { try? await Task.sleep(nanoseconds: 2_500_000_000); saveToast = nil }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
