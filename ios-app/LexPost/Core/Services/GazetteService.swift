import Foundation

final class GazetteService {
    static let shared = GazetteService()
    private let client = APIClient.shared

    func fetchUpdates(
        limit: Int = 20,
        offset: Int = 0,
        documentType: String? = nil
    ) async throws -> [LegalUpdate] {
        var path = "/gazette/?limit=\(limit)&offset=\(offset)"
        if let type = documentType {
            path += "&document_type=\(type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? type)"
        }
        return try await client.get(path)
    }

    func fetchUpdate(id: String) async throws -> LegalUpdate {
        return try await client.get("/gazette/\(id)")
    }

    /// Bugün DB'de kaç kayıt olduğunu döner. Scraping yapmaz.
    func fetchTodayCount() async -> Int {
        let response = try? await client.get("/gazette/today-count") as TodayCountResponse
        return response?.count ?? 0
    }
}

private struct TodayCountResponse: Decodable {
    let date: String
    let count: Int
}
