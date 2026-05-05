import Foundation
import SwiftUI

struct PricingInfo: Decodable {
    let monthlyPrice: String
    let yearlyPrice: String
    let yearlySavings: String
    let notificationTitle: String
    let notificationBody: String

    enum CodingKeys: String, CodingKey {
        case monthlyPrice       = "monthly_price"
        case yearlyPrice        = "yearly_price"
        case yearlySavings      = "yearly_savings"
        case notificationTitle  = "notification_title"
        case notificationBody   = "notification_body"
    }
}

@MainActor
final class PremiumService: ObservableObject {
    static let shared = PremiumService()

    @AppStorage("isPremium") private(set) var isPremium: Bool = false

    private let client = APIClient.shared
    private init() {}

    // MARK: - Promo Kod Doğrulama

    func validatePromoCode(_ code: String) async -> PromoResult {
        struct Req: Encodable { let code: String }
        struct Res: Decodable { let valid: Bool }
        do {
            let res: Res = try await client.post("/config/validate-promo", body: Req(code: code))
            if res.valid { isPremium = true }
            return res.valid ? .success : .invalid
        } catch {
            return .networkError
        }
    }

    // MARK: - Fiyat Bilgisi

    func fetchPricing() async -> PricingInfo? {
        try? await client.get("/config/pricing")
    }

    // MARK: - StoreKit (Apple Developer hesabı sonrası)
    func purchasePremium(plan: PremiumPlan) async -> Bool {
        // TODO: StoreKit 2
        return false
    }
}

enum PremiumPlan { case monthly, yearly }

enum PromoResult {
    case success, invalid, networkError

    var message: String {
        switch self {
        case .success:      return "Promosyon kodu onaylandı! Premium aktif."
        case .invalid:      return "Geçersiz promosyon kodu."
        case .networkError: return "Bağlantı hatası. Tekrar deneyin."
        }
    }
}
