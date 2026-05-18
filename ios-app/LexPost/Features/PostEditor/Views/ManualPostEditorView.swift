import SwiftUI
import PhotosUI
import Photos

struct ManualPostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userStore = UserImageStore.shared

    @State private var templates: [Template] = []
    @State private var selectedTemplate: Template? = nil
    @State private var isLoadingTemplates = false

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedStoredImageId: String? = nil
    @State private var customTitle: String = ""
    @State private var customText: String = ""
    @State private var customCta: String = ""
    @State private var textColorHex: String = "#FFFFFF"
    @State private var accentColorHex: String = "#D4AF37"
    @State private var fontSizeDelta: Int = 0
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var generatedImage: UIImage? = nil

    private let charLimit = 450
    private var canGenerate: Bool { selectedTemplate != nil || selectedImage != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Arka plan şablonları
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Arka Plan Şablonu")
                            .font(.headline)
                            .padding(.horizontal)

                        if isLoadingTemplates {
                            ProgressView().padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // TODO: v2 premium - block selection when template.isPro && !PremiumService.shared.isPremium, show PremiumUpgradeDialog
                                    ForEach(templates) { template in
                                        TemplateCard(
                                            template: template,
                                            isSelected: selectedTemplate?.id == template.id && selectedImage == nil
                                        ) {
                                            selectedTemplate = template
                                            selectedImage = nil
                                            selectedStoredImageId = nil
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Galeriden seç
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kendi Görselim")
                            .font(.headline)
                            .padding(.horizontal)

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 200)

                                if let img = selectedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 40))
                                            .foregroundColor(.accentColor)
                                        Text("Galeriden seç")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: selectedItem) {
                            Task {
                                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    selectedImage = img
                                    selectedStoredImageId = nil
                                    userStore.addImage(img)
                                }
                            }
                        }
                    }

                    // Kayıtlı görsellers
                    if !userStore.images.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Kayıtlı Görsellerim")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(userStore.images) { img in
                                        Button {
                                            if let uiImg = UIImage(contentsOfFile: userStore.localURL(for: img).path) {
                                                selectedImage = uiImg
                                                selectedStoredImageId = img.id
                                            }
                                        } label: {
                                            ZStack(alignment: .topTrailing) {
                                                if let uiImg = UIImage(contentsOfFile: userStore.localURL(for: img).path) {
                                                    Image(uiImage: uiImg)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 90, height: 90)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                }
                                                Button { userStore.removeImage(img) } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Color.black.opacity(0.6), in: Circle())
                                                }
                                                .padding(3)
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedStoredImageId == img.id ? appGold : Color.clear, lineWidth: 2.5)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Başlık
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Başlık")
                            .font(.headline)
                            .padding(.horizontal)
                        TextField("Gönderi başlığı", text: $customTitle)
                            .font(.body)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                            .padding(.horizontal)
                    }

                    // İçerik
                    EditorField(label: "İçerik") {
                        VStack(spacing: 6) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FormatButton(icon: "list.bullet", label: "Madde") { customText += "\n• " }
                                    FormatButton(icon: "arrow.turn.down.left", label: "Yeni Satır") { customText += "\n" }
                                    FormatButton(icon: "trash", label: "Temizle") { customText = "" }
                                }
                            }
                            let isOver = customText.count > charLimit
                            let isNear = customText.count > 380 && !isOver
                            TextEditor(text: $customText)
                                .font(.body)
                                .padding(8)
                                .frame(minHeight: 130, maxHeight: 200)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isOver ? Color.red : (isNear ? Color.orange : Color(.systemGray4)),
                                                lineWidth: isOver || isNear ? 1.5 : 1)
                                )
                            HStack(spacing: 4) {
                                if isOver {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundColor(.red)
                                    Text("Görsele sığmayacak kısımlar kesilebilir.").font(.caption2).foregroundColor(.red)
                                } else if isNear {
                                    Image(systemName: "exclamationmark.circle.fill").font(.caption2).foregroundColor(.orange)
                                    Text("Limite yaklaşıyorsunuz.").font(.caption2).foregroundColor(.orange)
                                }
                                Spacer()
                                Text("\(customText.count)/\(charLimit)")
                                    .font(.caption2)
                                    .foregroundColor(isOver ? .red : (isNear ? .orange : .secondary))
                                    .fontWeight(isOver || isNear ? .medium : .regular)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Dipnot
                    EditorField(label: "Dipnot", hint: "alt satır") {
                        TextField("Dipnot metni", text: $customCta)
                            .font(.body)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    .padding(.horizontal)

                    // Renkler
                    VStack(alignment: .leading, spacing: 12) {
                        ColorPickerRow(label: "Yazı Rengi", options: PostColorOption.textColors, selected: $textColorHex)
                        ColorPickerRow(label: "Vurgu Rengi", options: PostColorOption.accentColors, selected: $accentColorHex)
                    }
                    .padding(.horizontal)

                    // Yazı boyutu
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yazı Boyutu").font(.headline)
                        HStack(spacing: 12) {
                            ForEach([(-4, "Küçük"), (0, "Orta"), (6, "Büyük")], id: \.0) { delta, label in
                                FontStyleOption(label: label, isSelected: fontSizeDelta == delta) {
                                    fontSizeDelta = delta
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }

                    // Oluştur butonu
                    VStack(spacing: 8) {
                        if customText.count > charLimit {
                            Label("İçerik \(charLimit) karakteri aşıyor, görselde son kısımlar görünmeyebilir.", systemImage: "scissors")
                                .font(.caption).foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        Button {
                            Task { await generatePost() }
                        } label: {
                            Group {
                                if isGenerating {
                                    HStack { ProgressView().tint(.white); Text("Oluşturuluyor…") }
                                } else {
                                    Label("Görseli Hazırla", systemImage: "wand.and.stars")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canGenerate ? appGold : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canGenerate || isGenerating)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top)
            }
            .navigationTitle("Manuel Gönderi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { generatedImage.map { WrappedImage(image: $0) } },
                set: { if $0 == nil { generatedImage = nil } }
            )) { wrapped in
                ManualShareView(image: wrapped.image, onDismiss: { dismiss() })
            }
        }
        .task {
            isLoadingTemplates = true
            templates = (try? await PostService.shared.fetchTemplates()) ?? []
            selectedTemplate = templates.first
            isLoadingTemplates = false
        }
    }

    private func generatePost() async {
        isGenerating = true
        errorMessage = nil

        let title = customTitle.isEmpty ? nil : customTitle
        let cta   = customCta.isEmpty   ? nil : customCta

        do {
            let userBase64: String? = {
                guard let img = selectedImage, let data = img.jpegData(compressionQuality: 0.85) else { return nil }
                return data.base64EncodedString()
            }()

            generatedImage = try await PostService.shared.generatePost(
                legalUpdateId: nil,
                templateId: selectedTemplate?.id,
                fontStyle: "classic",
                userId: UserIdentifierService.userId,
                customText: customText,
                userImageBase64: userBase64,
                customCategory: nil,
                customTitle: title,
                customCta: cta,
                textColorHex: textColorHex,
                accentColorHex: accentColorHex,
                fontSizeDelta: fontSizeDelta
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}

// sheet(item:) için Identifiable wrapper
private struct WrappedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - ManualShareView

struct ManualShareView: View {
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
                Button { showShareSheet = true } label: {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appGold)
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
