import Foundation
import SwiftUI

enum PostEditorStep {
    case selectTemplate
    case editText
}

@MainActor
final class PostEditorViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var selectedTemplate: Template?
    @Published var selectedUserImage: UserStoredImage?
    @Published var selectedFontStyle = "classic"
    @Published var editableCategory: String = ""
    @Published var editableTitle: String = ""
    @Published var editableText: String = ""
    @Published var editableCta: String = "Detaylar için resmi gazeteyi inceleyin."
    @Published var textColorHex: String = "#FFFFFF"
    @Published var accentColorHex: String = "#D4AF37"
    @Published var fontSizeDelta: Int = 0
    @Published var generatedImage: UIImage?
    @Published var isLoadingTemplates = false
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var step: PostEditorStep = .selectTemplate

    let fontStyleOptions = [("classic", "Klasik (Playfair)"), ("modern", "Modern (Montserrat)")]
    private let postService = PostService.shared
    var userImageStore: UserImageStore { .shared }

    func loadTemplates() async {
        isLoadingTemplates = true
        do {
            templates = try await postService.fetchTemplates()
            selectedTemplate = templates.first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingTemplates = false
    }

    func prepareText(for update: LegalUpdate) {
        editableCategory = update.documentType
        editableTitle = update.title
        // İçerik alanı AI özetiyle başlar; kullanıcı düzenleyebilir veya silebilir
        editableText = update.cleanedSummary ?? ""
        editableCta = "Detaylar için resmi gazeteyi inceleyin."
    }

    func proceedToEditText(for update: LegalUpdate) {
        if editableText.isEmpty {
            prepareText(for: update)
        }
        step = .editText
    }

    func generatePost(legalUpdateId: String, userId: String) async {
        guard selectedTemplate != nil || selectedUserImage != nil else {
            errorMessage = "Lütfen bir şablon seçin."
            return
        }

        isGenerating = true
        errorMessage = nil

        // Kullanıcı görseli seçildiyse base64 encode et
        var userImageBase64: String? = nil
        if let userImage = selectedUserImage {
            let url = UserImageStore.shared.localURL(for: userImage)
            if let data = try? Data(contentsOf: url) {
                userImageBase64 = data.base64EncodedString()
            } else {
                errorMessage = "Görsel okunamadı."
                isGenerating = false
                return
            }
        }

        do {
            generatedImage = try await postService.generatePost(
                legalUpdateId: legalUpdateId,
                templateId: selectedTemplate?.id,
                fontStyle: selectedFontStyle,
                userId: userId,
                customText: editableText,
                userImageBase64: userImageBase64,
                customCategory: editableCategory.isEmpty ? nil : editableCategory,
                customTitle: editableTitle.isEmpty ? nil : editableTitle,
                customCta: editableCta.isEmpty ? nil : editableCta,
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
