import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var premium = PremiumService.shared
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Hesap
                Section("Hesap") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(premium.isPremium ? appGold.opacity(0.15) : Color.accentColor.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: premium.isPremium ? "crown.fill" : "person.fill")
                                .font(.title3)
                                .foregroundColor(premium.isPremium ? appGold : .accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(premium.isPremium ? "Premium Üyelik" : "Standart Üyelik")
                                .font(.headline)
                            Text(premium.isPremium ? "Tüm özellikler aktif" : "Sınırlı erişim")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !premium.isPremium {
                            Button("Premium'a Geç") { showPaywall = true }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(appGold.opacity(0.15))
                                .foregroundColor(appGold)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .sheet(isPresented: $showPaywall) { PremiumPaywallView() }

                // Tema
                Section("Tercihler") {
                    HStack {
                        Label("Tema", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                        Spacer()
                        Picker("", selection: $isDarkMode) {
                            Text("Koyu").tag(true)
                            Text("Açık").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                }

                Section("Bildirimler") {
                    // Toggle
                    HStack {
                        Label("Bildirimler", systemImage: "bell.fill")
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { viewModel.notificationsEnabled },
                                set: { newVal in
                                    Task { await viewModel.toggleNotifications(newVal) }
                                }
                            ))
                            .labelsHidden()
                        }
                    }

                    // İzin reddedilmişse uyarı
                    if viewModel.permissionDenied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Bildirimlere izin verilmedi.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Ayarları Aç") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    }

                    // Saat/dakika seçici — bildirim açıksa göster
                    if viewModel.notificationsEnabled && !viewModel.permissionDenied {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Bildirim Saati", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            DatePicker(
                                "",
                                selection: $viewModel.notificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)

                            Button {
                                Task { await viewModel.saveNotificationTime() }
                            } label: {
                                HStack {
                                    if viewModel.isSaving {
                                        ProgressView().scaleEffect(0.8).tint(.white)
                                    }
                                    Text(viewModel.timeSaved ? "Kaydedildi ✓" : "Kaydet")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(viewModel.timeSaved ? Color.green : Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(viewModel.isSaving)

                            Text("Her gün seçilen saatte bildirim alırsınız.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Promosyon Kodu
                if !premium.isPremium {
                    Section("Promosyon Kodu") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(appGold)
                                    .font(.subheadline)
                                TextField("Kodu girin", text: $viewModel.promoCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .onSubmit { Task { await viewModel.submitPromoCode() } }
                                if viewModel.isValidatingPromo {
                                    ProgressView().scaleEffect(0.8)
                                } else if !viewModel.promoCode.isEmpty {
                                    Button {
                                        Task { await viewModel.submitPromoCode() }
                                    } label: {
                                        Text("Uygula")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(appGold.opacity(0.15))
                                            .foregroundColor(appGold)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            if let msg = viewModel.promoStatus.message {
                                Label(msg, systemImage: viewModel.promoStatus.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(viewModel.promoStatus.isError ? .red : .green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Uygulama
                Section("Uygulama") {
                    HStack {
                        Label("Versiyon", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://resmigazete.gov.tr")!) {
                        Label("Resmi Gazete", systemImage: "newspaper")
                    }
                    Label("Gizlilik Politikası", systemImage: "hand.raised")
                }
            }
            .navigationTitle("Ayarlar")
            .task {
                viewModel.loadSettings()
                await viewModel.checkPermissionStatus()
            }
        }
    }


}
