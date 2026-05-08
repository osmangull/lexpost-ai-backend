import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let hourKey    = "lexpost_notification_hour"
    private let minuteKey  = "lexpost_notification_minute"
    private let enabledKey = "lexpost_notifications_enabled"
    private let notifID    = "lexpost_daily_gazette"

    // MARK: - Stored preferences

    var notificationHour: Int {
        get { let v = UserDefaults.standard.integer(forKey: hourKey); return v == 0 ? 8 : v }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    var notificationMinute: Int {
        get { UserDefaults.standard.integer(forKey: minuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    var notificationTime: Date {
        get {
            var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            c.hour = notificationHour; c.minute = notificationMinute
            return Calendar.current.date(from: c) ?? Date()
        }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notificationHour   = c.hour   ?? 8
            notificationMinute = c.minute ?? 0
        }
    }

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private init() {}

    // MARK: - Permission

    /// İzin ister. Sonuç: izin verildi mi?
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule / Cancel

    /// Günlük tekrarlayan bildirimi kur. title/body verilmezse kayıtlı değerleri kullanır.
    func scheduleDaily(at date: Date, title: String? = nil, body: String? = nil) {
        cancelAll()
        notificationTime = date

        let content = UNMutableNotificationContent()
        content.title = title ?? savedNotificationTitle
        content.body  = body  ?? savedNotificationBody
        content.sound = .default

        var comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        comps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // Bildirim metnini locale sakla (son çekilen backend değeri)
    var savedNotificationTitle: String {
        get { UserDefaults.standard.string(forKey: "lexpost_notif_title") ?? "LexPost" }
        set { UserDefaults.standard.set(newValue, forKey: "lexpost_notif_title") }
    }
    var savedNotificationBody: String {
        get { UserDefaults.standard.string(forKey: "lexpost_notif_body") ?? "Günlük gazeten hazır, incelemek ister misin? 📰" }
        set { UserDefaults.standard.set(newValue, forKey: "lexpost_notif_body") }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
    }

    // MARK: - Enable / Disable

    func setNotificationsEnabled(_ enabled: Bool) async {
        notificationsEnabled = enabled
        if enabled {
            scheduleDaily(at: notificationTime)
        } else {
            cancelAll()
        }
    }

    func updateNotificationTime(_ date: Date) async {
        notificationTime = date
        if notificationsEnabled {
            scheduleDaily(at: date)
        }
    }
}
