import SwiftUI

// MARK: - Shared palette helpers

let appGold    = Color(red: 0.831, green: 0.686, blue: 0.216)
let appGoldDim = Color(red: 0.831, green: 0.686, blue: 0.216).opacity(0.70)
let appNavy    = Color(red: 0.051, green: 0.106, blue: 0.165)
let appCardDark = Color(red: 0.07,  green: 0.130, blue: 0.190)

func appDocColor(_ type: String) -> Color {
    switch type {
    case "Yönetmelik": return Color(red: 0.33, green: 0.62, blue: 1.00)
    case "Tebliğ":     return Color(red: 1.00, green: 0.65, blue: 0.20)
    case "Karar":      return Color(red: 0.72, green: 0.45, blue: 1.00)
    default:           return Color.secondary
    }
}

// MARK: - DashboardViewNew

struct DashboardViewNew: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var premium = PremiumService.shared
    @State private var navigationPath = NavigationPath()
    @State private var showManualEditor = false
    @State private var showUpgradeDialog = false
    @State private var searchText = ""
    @Environment(\.colorScheme) private var scheme

    private var bg:   Color { scheme == .dark ? appNavy    : Color(.systemBackground) }
    private var text: Color { scheme == .dark ? .white      : Color(.label) }

    private var filteredUpdates: [LegalUpdate] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return viewModel.updates
        }
        let query = searchText.lowercased()
        return viewModel.updates.filter {
            $0.title.lowercased().contains(query) ||
            ($0.cleanedSummary?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            NavigationStack(path: $navigationPath) {
                ZStack {
                    bg.ignoresSafeArea()
                    VStack(spacing: 0) {
                        headerBar
                        filterBar
                        searchBar
                        contentArea
                    }
                    .navigationBarHidden(true)
                    .navigationDestination(for: LegalUpdate.self) { update in
                        UpdateDetailViewNew(update: update)
                    }
                }
            }

            // FAB
            if navigationPath.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if premium.isPremium {
                                showManualEditor = true
                            } else {
                                showUpgradeDialog = true
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(appNavy)
                                    .frame(width: 56, height: 56)
                                    .background(appGold)
                                    .clipShape(Circle())
                                    .shadow(color: appGold.opacity(0.45), radius: 12, x: 0, y: 5)
                                if !premium.isPremium {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(appNavy)
                                        .padding(4)
                                        .background(appGold)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(appNavy, lineWidth: 1.5))
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }

            // Toast
            VStack {
                Spacer()
                if let msg = viewModel.toastMessage {
                    Text(msg)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: viewModel.toastMessage)
            .zIndex(10)
        }
        .sheet(isPresented: $showManualEditor) { ManualPostEditorView() }
        .sheet(isPresented: $showUpgradeDialog) {
            PremiumUpgradeDialog(
                featureTitle: "Görsel İçerik Oluşturucu",
                featureDescription: "Resmi Gazete yayınlarından profesyonel sosyal medya görseli oluşturmak için Premium'a geçin.",
                isPresented: $showUpgradeDialog
            )
        }
        .task { await viewModel.loadUpdates() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LEXPOST")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(appGoldDim)
                    .kerning(3)
                Text("Resmi Gazete")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(text)
            }
            Spacer()
            if viewModel.isLoading && !viewModel.updates.isEmpty {
                ProgressView().tint(appGold).scaleEffect(0.85)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(bg)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NewFilterPill(title: "Tümü", isSelected: viewModel.selectedFilter == nil, scheme: scheme) {
                    Task { await viewModel.applyFilter(nil) }
                }
                ForEach(viewModel.filterOptions, id: \.self) { opt in
                    NewFilterPill(title: opt, isSelected: viewModel.selectedFilter == opt, scheme: scheme) {
                        Task { await viewModel.applyFilter(opt) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(bg.shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 3))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(searchText.isEmpty ? (scheme == .dark ? .white.opacity(0.3) : Color(.tertiaryLabel)) : appGold)

            TextField(
                viewModel.selectedFilter.map { "\($0) içinde ara…" } ?? "Tüm yayınlarda ara…",
                text: $searchText
            )
            .font(.system(size: 14))
            .foregroundColor(text)
            .tint(appGold)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.25)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(scheme == .dark ? .white.opacity(0.35) : Color(.tertiaryLabel))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(scheme == .dark ? appCardDark : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    searchText.isEmpty
                        ? (scheme == .dark ? Color.white.opacity(0.07) : Color(.systemGray4))
                        : appGold.opacity(0.5),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(bg)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.updates.isEmpty {
            Spacer()
            ProgressView().tint(appGold)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.updates.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash").font(.system(size: 44)).foregroundColor(appGoldDim)
                Text(error).multilineTextAlignment(.center).foregroundColor(text.opacity(0.55)).font(.subheadline)
                Button("Tekrar Dene") { Task { await viewModel.loadUpdates(refresh: true) } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(appNavy)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(appGold).clipShape(Capsule())
            }
            .padding()
            Spacer()
        } else if viewModel.updates.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 44)).foregroundColor(appGoldDim)
                Text(viewModel.selectedFilter.map { "\($0) kategorisinde yayın bulunamadı." } ?? "Henüz yayın bulunamadı.")
                    .foregroundColor(text.opacity(0.5)).font(.subheadline).multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredUpdates.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(appGoldDim)
                            Text("\"\(searchText)\" için sonuç bulunamadı.")
                                .font(.subheadline)
                                .foregroundColor(text.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(filteredUpdates) { update in
                            LegalUpdateCardNew(update: update, navigationPath: $navigationPath)
                                .task {
                                    if searchText.isEmpty {
                                        await viewModel.loadMoreIfNeeded(currentItem: update)
                                    }
                                }
                        }
                        if viewModel.isLoading && searchText.isEmpty {
                            ProgressView().tint(appGold).padding(.vertical, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .refreshable { await viewModel.loadUpdates(refresh: true, checkForNew: true) }
        }
    }
}

// MARK: - Filter Pill

private struct NewFilterPill: View {
    let title: String
    let isSelected: Bool
    let scheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? appNavy : (scheme == .dark ? .white.opacity(0.65) : Color(.label).opacity(0.7)))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(appGold)
                    } else {
                        Capsule().stroke(
                            scheme == .dark ? Color.white.opacity(0.15) : Color(.systemGray3),
                            lineWidth: 1
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Card

struct LegalUpdateCardNew: View {
    let update: LegalUpdate
    @Binding var navigationPath: NavigationPath
    @Environment(\.colorScheme) private var scheme

    private var cardBg: Color {
        scheme == .dark ? appCardDark : Color(.secondarySystemBackground)
    }
    private var titleColor: Color {
        scheme == .dark ? .white.opacity(0.92) : Color(.label)
    }
    private var summaryColor: Color {
        scheme == .dark ? .white.opacity(0.50) : Color(.secondaryLabel)
    }
    private var metaColor: Color {
        scheme == .dark ? .white.opacity(0.25) : Color(.tertiaryLabel)
    }
    private var borderColor: Color {
        scheme == .dark ? .white.opacity(0.06) : Color(.systemGray5)
    }

    var body: some View {
        Button { navigationPath.append(update) } label: {
            HStack(spacing: 0) {
                // Left accent bar
                Rectangle()
                    .fill(appDocColor(update.documentType))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(update.documentType.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(appDocColor(update.documentType))
                            .kerning(1.2)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(appDocColor(update.documentType).opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                        Image(systemName: "calendar").font(.system(size: 9)).foregroundColor(appGoldDim)
                        Text(update.formattedDate).font(.system(size: 11)).foregroundColor(appGoldDim)
                    }

                    Text(update.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(titleColor)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let summary = update.cleanedSummary {
                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundColor(summaryColor)
                            .lineLimit(2)
                    }

                    HStack {
                        Text("Sayı: \(update.gazetteNumber)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(metaColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(metaColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.07), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
