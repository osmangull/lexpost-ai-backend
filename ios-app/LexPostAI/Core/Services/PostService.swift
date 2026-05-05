import Foundation
import UIKit

struct GeneratePostRequest: Encodable {
    let legalUpdateId: String?
    let templateId: String?
    let userImageBase64: String?
    let fontStyle: String
    let userId: String
    let customText: String?
    let customCategory: String?
    let customTitle: String?
    let customCta: String?
    let textColor: String?
    let accentColor: String?
    let fontSizeDelta: Int

    enum CodingKeys: String, CodingKey {
        case legalUpdateId = "legal_update_id"
        case templateId = "template_id"
        case userImageBase64 = "user_image_base64"
        case fontStyle = "font_style"
        case userId = "user_id"
        case customText = "custom_text"
        case customCategory = "custom_category"
        case customTitle = "custom_title"
        case customCta = "custom_cta"
        case textColor = "text_color"
        case accentColor = "accent_color"
        case fontSizeDelta = "font_size_delta"
    }
}

struct ManualPostRequest: Encodable {
    let userImageBase64: String
    let customText: String
    let fontStyle: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userImageBase64 = "user_image_base64"
        case customText = "custom_text"
        case fontStyle = "font_style"
        case userId = "user_id"
    }
}

final class PostService {
    static let shared = PostService()
    private let client = APIClient.shared

    func generatePost(
        legalUpdateId: String?,
        templateId: String?,
        fontStyle: String,
        userId: String,
        customText: String? = nil,
        userImageBase64: String? = nil,
        customCategory: String? = nil,
        customTitle: String? = nil,
        customCta: String? = nil,
        textColorHex: String? = nil,
        accentColorHex: String? = nil,
        fontSizeDelta: Int = 0
    ) async throws -> UIImage {
        let body = GeneratePostRequest(
            legalUpdateId: legalUpdateId,
            templateId: templateId,
            userImageBase64: userImageBase64,
            fontStyle: fontStyle,
            userId: userId,
            customText: customText,
            customCategory: customCategory,
            customTitle: customTitle,
            customCta: customCta,
            textColor: textColorHex,
            accentColor: accentColorHex,
            fontSizeDelta: fontSizeDelta
        )
        let data = try await client.postData("/posts/generate", body: body)
        guard let image = UIImage(data: data) else {
            throw APIError.decodingError(NSError(domain: "PostService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Görsel verisi işlenemedi."]))
        }
        return image
    }

    func generateManualPost(
        userImageBase64: String,
        customText: String,
        fontStyle: String,
        userId: String
    ) async throws -> UIImage {
        let body = ManualPostRequest(
            userImageBase64: userImageBase64,
            customText: customText,
            fontStyle: fontStyle,
            userId: userId
        )
        let data = try await client.postData("/posts/generate-manual", body: body)
        guard let image = UIImage(data: data) else {
            throw APIError.decodingError(NSError(domain: "PostService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Görsel verisi işlenemedi."]))
        }
        return image
    }

    func fetchTemplates() async throws -> [Template] {
        return try await client.get("/templates/")
    }
}
