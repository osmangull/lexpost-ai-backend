import Foundation

struct LegalUpdate: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let documentType: String
    let gazetteDate: String
    let gazetteNumber: String
    let sourceUrl: String
    let rawContent: String?
    let aiSummary: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case documentType = "document_type"
        case gazetteDate = "gazette_date"
        case gazetteNumber = "gazette_number"
        case sourceUrl = "source_url"
        case rawContent = "raw_content"
        case aiSummary = "ai_summary"
        case createdAt = "created_at"
    }

    /// Groq'tan gelen markdown kalıplarını temizlenmiş özet
    var cleanedSummary: String? {
        guard let s = aiSummary, !s.isEmpty else { return nil }
        var result = s
        // **bold** → bold
        result = result.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        // *italic* → italic
        result = result.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        // [köşeli parantez içi] → kaldır
        result = result.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
        // Fazla boşlukları temizle
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    var documentTypeEmoji: String {
        switch documentType {
        case "Yönetmelik": return "📋"
        case "Tebliğ": return "📢"
        case "Karar": return "⚖️"
        default: return "📄"
        }
    }

    var formattedDate: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "d MMMM yyyy"
        output.locale = Locale(identifier: "tr_TR")
        if let date = input.date(from: gazetteDate) {
            return output.string(from: date)
        }
        return gazetteDate
    }

    /// İlk anlamlı içerik satırlarından oluşan önizleme (max ~350 karakter)
    var contentPreview: String? {
        guard let raw = rawContent, !raw.isEmpty else { return nil }
        let junkPatterns = ["CUMHURBAŞKANI KARARI", "Recep Tayyip ERDOĞAN", "CUMHURBAŞKANI", "Resmî Gazete", "T.C. CUMHURBAŞKANLı"]
        let cleaned = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard line.count >= 8 else { return false }
                let letters = line.filter { $0.isLetter }.count
                guard letters > 0 else { return false }
                let letterRatio = Double(letters) / Double(line.count)
                guard letterRatio >= 0.40 else { return false }
                // Büyük harf ağırlıklı kısa satırlar → başlık/imza bloğu
                let upper = line.filter { $0.isUppercase }.count
                if Double(upper) / Double(letters) > 0.65 && line.count < 100 { return false }
                // Bilinen junk kalıpları
                if junkPatterns.contains(where: { line.contains($0) }) { return false }
                // Sayfa numarası vb.
                if line.range(of: #"^\d+\s*/\s*\d+$"#, options: .regularExpression) != nil { return false }
                return true
            }
            .prefix(10)
            .joined(separator: " ")

        guard !cleaned.isEmpty else { return nil }
        if cleaned.count > 380 {
            var result = String(cleaned.prefix(380))
            if let lastSpace = result.lastIndex(of: " ") {
                result = String(result[..<lastSpace])
            }
            return result + "…"
        }
        return cleaned
    }
}
