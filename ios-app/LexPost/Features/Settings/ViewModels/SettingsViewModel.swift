import Foundation
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = false
    @Published var notificationTime: Date = Date()
    @Published var permissionDenied: Bool = false
    @Published var isSaving: Bool = false
    @Published var timeSaved: Bool = false

    private let service = NotificationService.shared
    private let premiumService = PremiumService.shared
    private var saveTask: Task<Void, Never>?

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

}
