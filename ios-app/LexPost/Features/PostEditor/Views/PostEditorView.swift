import SwiftUI
import PhotosUI

struct PostEditorView: View {
    let legalUpdate: LegalUpdate
    @StateObject private var viewModel = PostEditorViewModel()
    @ObservedObject private var userImageStore = UserImageStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingTemplates {
                    ProgressView("Şablonlar yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = viewModel.generatedImage {
                    GeneratedPostView(image: image, onDismiss: { dismiss() })
                } else {
                    switch viewModel.step {
                    case .selectTemplate:
                        templateStepView
                    case .editText:
                        editTextStepView
                    }
                }
            }
            .navigationTitle("Görsel Oluştur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.step == .selectTemplate {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { viewModel.step = .selectTemplate }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Geri")
                            }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadTemplates()
            viewModel.prepareText(for: legalUpdate)
        }
    }

    // MARK: - Step 1: Template seçimi
    private var templateStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Haber başlığı
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haber")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(legalUpdate.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Hazır şablonlar
                templateSection

                // Kullanıcı görselleri
                userImagesSection

                // Yazı tipi
                fontStyleSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // İleri butonu
                Button {
                    viewModel.proceedToEditText(for: legalUpdate)
                } label: {
                    Label("İleri: Metni Düzenle", systemImage: "chevron.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appGold)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.selectedTemplate == nil && viewModel.selectedUserImage == nil)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top)
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arka Plan Şablonu")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.templates) { template in
                        TemplateCard(
                            template: template,
                            isSelected: viewModel.selectedTemplate?.id == template.id && viewModel.selectedUserImage == nil
                        ) {
                            viewModel.selectedTemplate = template
                            viewModel.selectedUserImage = nil
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var userImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kendi Görsellerim")
                    .font(.headline)
                Spacer()
                PhotosPicker(selection: Binding(
                    get: { nil as PhotosPickerItem? },
                    set: { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                userImageStore.addImage(img)
                            }
                        }
                    }
                ), matching: .images) {
                    Label("Ekle", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            if userImageStore.images.isEmpty {
                Text("Galeriden görsel eklemek için + butonuna dokunun")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(userImageStore.images) { img in
                            UserImageCard(
                                image: img,
                                store: userImageStore,
                                isSelected: viewModel.selectedUserImage?.id == img.id
                            ) {
                                viewModel.selectedUserImage = img
                                viewModel.selectedTemplate = nil
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var fontStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yazı Tipi")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                ForEach(viewModel.fontStyleOptions, id: \.0) { value, label in
                    FontStyleOption(
                        label: label,
                        isSelected: viewModel.selectedFontStyle == value
                    ) {
                        viewModel.selectedFontStyle = value
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Step 2: Metin düzenleme
    private var editTextStepView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- Kategori ---
                EditorField(label: "Kategori", hint: "ör. Yönetmelik") {
                    TextField("Kategori", text: $viewModel.editableCategory)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // --- Başlık ---
                EditorField(label: "Başlık") {
                    TextEditor(text: $viewModel.editableTitle)
                        .font(.body)
                        .padding(8)
                        .frame(minHeight: 80, maxHeight: 120)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                }

                // --- İçerik ---
                EditorField(label: "İçerik") {
                    VStack(spacing: 6) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FormatButton(icon: "list.bullet", label: "Madde") { viewModel.editableText += "\n• " }
                                FormatButton(icon: "arrow.turn.down.left", label: "Yeni Satır") { viewModel.editableText += "\n" }
                                FormatButton(icon: "trash", label: "Temizle") { viewModel.editableText = "" }
                            }
                        }
                        let charCount = viewModel.editableText.count
                        let charLimit = 450
                        let isOverLimit = charCount > charLimit
                        let isNearLimit = charCount > 380 && !isOverLimit
                        TextEditor(text: $viewModel.editableText)
                            .font(.body)
                            .padding(8)
                            .frame(minHeight: 130, maxHeight: 200)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isOverLimit ? Color.red : (isNearLimit ? Color.orange : Color(.systemGray4)),
                                        lineWidth: isOverLimit || isNearLimit ? 1.5 : 1
                                    )
                            )
                        HStack(spacing: 4) {
                            if isOverLimit {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("Görsele sığmayacak kısımlar kesilebilir.")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            } else if isNearLimit {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text("Limite yaklaşıyorsunuz.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Text("\(charCount)/\(charLimit)")
                                .font(.caption2)
                                .foregroundColor(isOverLimit ? .red : (isNearLimit ? .orange : .secondary))
                                .fontWeight(isOverLimit || isNearLimit ? .medium : .regular)
                        }
                    }
                }

                // --- Dipnot ---
                EditorField(label: "Dipnot", hint: "alt satır") {
                    TextField("Dipnot metni", text: $viewModel.editableCta)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // --- Renk seçimi ---
                VStack(alignment: .leading, spacing: 12) {
                    ColorPickerRow(
                        label: "Yazı Rengi",
                        options: PostColorOption.textColors,
                        selected: $viewModel.textColorHex
                    )
                    ColorPickerRow(
                        label: "Vurgu Rengi",
                        options: PostColorOption.accentColors,
                        selected: $viewModel.accentColorHex
                    )
                }

                // --- Font boyutu ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yazı Boyutu")
                        .font(.headline)
                    HStack(spacing: 12) {
                        ForEach([(-4, "Küçük"), (0, "Orta"), (6, "Büyük")], id: \.0) { delta, label in
                            FontStyleOption(label: label, isSelected: viewModel.fontSizeDelta == delta) {
                                viewModel.fontSizeDelta = delta
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }

                // --- Görsel Oluştur ---
                VStack(spacing: 8) {
                    if viewModel.editableText.count > 450 {
                        Label("İçerik \(450) karakteri aşıyor, görselde son kısımlar görünmeyebilir.", systemImage: "scissors")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    Button {
                        Task { await viewModel.generatePost(legalUpdateId: legalUpdate.id, userId: UserIdentifierService.userId) }
                    } label: {
                        Group {
                            if viewModel.isGenerating {
                                HStack { ProgressView().tint(.white); Text("Oluşturuluyor…") }
                            } else {
                                Label("Görsel Oluştur", systemImage: "wand.and.stars")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appGold)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isGenerating)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - EditorField
struct EditorField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.headline)
                if let hint { Text(hint).font(.caption).foregroundColor(.secondary) }
            }
            content()
        }
    }
}

// MARK: - ColorPickerRow
struct PostColorOption {
    let hex: String
    let name: String

    static let textColors: [PostColorOption] = [
        .init(hex: "#FFFFFF", name: "Beyaz"),
        .init(hex: "#F5F0E0", name: "Krem"),
        .init(hex: "#000000", name: "Siyah"),
        .init(hex: "#0D1B2A", name: "Lacivert"),
    ]
    static let accentColors: [PostColorOption] = [
        .init(hex: "#D4AF37", name: "Altın"),
        .init(hex: "#FFFFFF", name: "Beyaz"),
        .init(hex: "#2563EB", name: "Mavi"),
        .init(hex: "#DC2626", name: "Kırmızı"),
        .init(hex: "#0D9488", name: "Teal"),
        .init(hex: "#EA580C", name: "Turuncu"),
    ]
}

struct ColorPickerRow: View {
    let label: String
    let options: [PostColorOption]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 2)
                    ForEach(options, id: \.hex) { opt in
                        Button {
                            selected = opt.hex
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: opt.hex))
                                        .frame(width: 34, height: 34)
                                        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                                    Circle()
                                        .stroke(
                                            selected == opt.hex ? appGold : Color(.systemGray3),
                                            lineWidth: selected == opt.hex ? 3 : 1
                                        )
                                        .frame(width: 40, height: 40)
                                }
                                .frame(width: 40, height: 40)
                                Text(opt.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(width: 2)
                }
                .padding(.vertical, 6)
            }
            .clipped(antialiased: false)
        }
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - UserImageCard
struct UserImageCard: View {
    let image: UserStoredImage
    let store: UserImageStore
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                if let uiImage = UIImage(contentsOfFile: store.localURL(for: image).path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                }

                // Sil butonu
                Button {
                    store.removeImage(image)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? appGold : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reused components
struct TemplateCard: View {
    let template: Template
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)

                    if let urlStr = template.previewUrl ?? template.backgroundUrl,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "photo").foregroundColor(.secondary)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "photo").foregroundColor(.secondary)
                    }

                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? appGold : Color.clear, lineWidth: 2.5))

                Text(template.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FormatButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .clipShape(Capsule())
        }
    }
}

struct FontStyleOption: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? appGold.opacity(0.15) : Color(.systemGray6))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? appGold : Color.clear, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
