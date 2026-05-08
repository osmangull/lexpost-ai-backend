import Foundation
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTime: Date = Date()
    @Published var permissionDenied: Bool = false
    @Published var isSaving: Bool = false
    @Published var timeSaved: Bool = false

    // Promo kod
    @Published var promoCode: String = ""
    @Published var promoStatus: PromoStatus = .idle
    @Published var isValidatingPromo: Bool = false

    private let service = NotificationService.shared
    private let premiumService = PremiumService.shared
    private var saveTask: Task<Void, Never>?

    enum PromoStatus: Equatable {
        case idle, success, invalid, networkError
        var message: String? {
            switch self {
            case .idle:         return nil
            case .success:      return "Promosyon kodu onaylandı! Premium aktif."
            case .invalid:      return "Geçersiz promosyon kodu."
            case .networkError: return "Bağlantı hatası. Tekrar deneyin."
            }
        }
        var isError: Bool { self == .invalid || self == .networkError }
    }

    func loadSettings() {
        notificationsEnabled = service.notificationsEnabled
        notificationTime = service.notificationTime
    }

    func checkPermissionStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        permissionDenied = s.authorizationStatus == .denied
    }

    func toggleNotifications(_ enabled: Bool) async {
        isSaving = true
        if enabled {
            let s = await UNUserNotificationCenter.current().notificationSettings()
            if s.authorizationStatus == .denied {
                permissionDenied = true
                isSaving = false
                return
            }
            if s.authorizationStatus == .notDetermined {
                let granted = await service.requestPermission()
                if !granted {
                    permissionDenied = true
                    isSaving = false
                    return
                }
            }
        }
        await service.setNotificationsEnabled(enabled)
        notificationsEnabled = service.notificationsEnabled
        isSaving = false
    }

    func onTimeChanged(_ date: Date) {
        notificationTime = date
        timeSaved = false
    }

    func saveNotificationTime() async {
        isSaving = true
        // Backend'den güncel bildirim metnini çek, kaydet
        if let info = await premiumService.fetchPricing() {
            service.savedNotificationTitle = info.notificationTitle
            service.savedNotificationBody  = info.notificationBody
        }
        await service.updateNotificationTime(notificationTime)
        isSaving = false
        timeSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            timeSaved = false
        }
    }

    func submitPromoCode() async {
        guard !promoCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isValidatingPromo = true
        promoStatus = .idle
        let result = await premiumService.validatePromoCode(promoCode)
        switch result {
        case .success:      promoStatus = .success
        case .invalid:      promoStatus = .invalid
        case .networkError: promoStatus = .networkError
        }
        isValidatingPromo = false
    }
}
