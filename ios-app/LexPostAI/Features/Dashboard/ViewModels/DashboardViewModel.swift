import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var updates: [LegalUpdate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: String? = nil
    @Published var toastMessage: String? = nil

    private let gazetteService = GazetteService.shared
    private var currentOffset = 0
    private let pageSize = 20
    private(set) var hasMore = true

    let filterOptions = ["Yönetmelik", "Tebliğ", "Karar"]

    func loadUpdates(refresh: Bool = false, checkForNew: Bool = false) async {
        if checkForNew {
            // Pull-to-refresh: mevcut yüklemeyi beklemeden çalış
        } else {
            guard !isLoading else { return }
        }

        if refresh {
            currentOffset = 0
            hasMore = true
        }

        if checkForNew {
            let firstIdBefore = updates.first?.id
            do {
                let newUpdates = try await gazetteService.fetchUpdates(
                    limit: pageSize, offset: 0, documentType: selectedFilter
                )
                let hasNew = newUpdates.first?.id != firstIdBefore
                updates = newUpdates
                currentOffset = newUpdates.count
                hasMore = newUpdates.count == pageSize
                showToast(hasNew ? "Yeni yayınlar eklendi." : "İçerik zaten güncel.")
            } catch {
                showToast("Güncelleme kontrol edilemedi.")
            }
            return
        }

        guard hasMore else { return }

        isLoading = true
        errorMessage = nil

        do {
            let newUpdates = try await gazetteService.fetchUpdates(
                limit: pageSize,
                offset: currentOffset,
                documentType: selectedFilter
            )
            if refresh {
                updates = newUpdates
            } else {
                let existingIds = Set(updates.map { $0.id })
                let unique = newUpdates.filter { !existingIds.contains($0.id) }
                updates.append(contentsOf: unique)
            }
            currentOffset += newUpdates.count
            hasMore = newUpdates.count == pageSize
        } catch is CancellationError {
            // Swift Task cancelled — mevcut listeyi koru, hata gösterme
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession cancelled (refresh gesture iptal edildi) — sessizce geç
        } catch {
            if updates.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func applyFilter(_ filter: String?) async {
        selectedFilter = filter
        await loadUpdates(refresh: true, checkForNew: false)
    }

    func loadMoreIfNeeded(currentItem: LegalUpdate) async {
        guard let last = updates.last, last.id == currentItem.id else { return }
        await loadUpdates()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 sn
            toastMessage = nil
        }
    }
}
