import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showManualEditor = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {

                VStack(spacing: 0) {
                    filterBar
                    content
                }
                .navigationTitle("Resmi Gazete")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.isLoading && !viewModel.updates.isEmpty {
                            ProgressView()
                        } else {
                            EmptyView()
                        }
                    }
                }
                .navigationDestination(for: LegalUpdate.self) { update in
                    UpdateDetailView(update: update)
                }
            }

            // FAB — sadece ana ekranda görünür
            if navigationPath.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showManualEditor = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(appGold)
                                .clipShape(Circle())
                                .shadow(color: appGold.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }

            // Toast
            if let msg = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4), value: viewModel.toastMessage)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showManualEditor) {
            ManualPostEditorView()
        }
        .task {
            await viewModel.loadUpdates()
        }
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        title: "Tümü",
                        isSelected: viewModel.selectedFilter == nil
                    ) {
                        Task { await viewModel.applyFilter(nil) }
                    }
                    ForEach(viewModel.filterOptions, id: \.self) { option in
                        FilterChip(
                            title: option,
                            isSelected: viewModel.selectedFilter == option
                        ) {
                            Task { await viewModel.applyFilter(option) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            Divider()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.updates.isEmpty {
            Spacer()
            ProgressView("Yükleniyor...")
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.updates.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("Tekrar Dene") {
                    Task { await viewModel.loadUpdates(refresh: true) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            Spacer()
        } else if viewModel.updates.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: viewModel.selectedFilter == nil ? "newspaper" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text(viewModel.selectedFilter.map { "\($0) kategorisinde yayın bulunamadı." }
                     ?? "Henüz yayın bulunamadı.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            List {
                ForEach(viewModel.updates) { update in
                    NavigationLink(value: update) {
                        LegalUpdateRow(update: update)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: update)
                    }
                }
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.loadUpdates(refresh: true, checkForNew: true)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? appGold : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct LegalUpdateRow: View {
    let update: LegalUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(update.documentTypeEmoji + " " + update.documentType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor.opacity(0.15))
                    .foregroundColor(typeColor)
                    .clipShape(Capsule())
                Spacer()
                Text(update.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(update.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(3)

            if let summary = update.cleanedSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        switch update.documentType {
        case "Yönetmelik": return .blue
        case "Tebliğ": return .orange
        case "Karar": return .purple
        default: return .gray
        }
    }
}
