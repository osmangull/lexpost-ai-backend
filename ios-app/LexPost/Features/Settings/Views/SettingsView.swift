import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        NavigationStack {
            List {
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
                                .background(viewModel.timeSaved ? Color.green : appGold)
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
                    Link(destination: URL(string: "https://berkaykosak.github.io/lexpost-legal/privacy")!) {
                        Label("Gizlilik Politikası", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://berkaykosak.github.io/lexpost-legal/terms")!) {
                        Label("Kullanım Koşulları", systemImage: "doc.text")
                    }
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
