import Foundation
import UIKit

/// Kullanıcının kendi galeri görsellerini Documents dizininde saklar,
/// listeyi UserDefaults'ta tutar.
final class UserImageStore: ObservableObject {
    static let shared = UserImageStore()

    @Published private(set) var images: [UserStoredImage] = []

    private let defaultsKey = "lexpost_user_images_v1"
    private let docsDir: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UserImages", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Public

    func addImage(_ uiImage: UIImage) {
        let id = UUID().uuidString
        let filename = "\(id).jpg"
        let url = docsDir.appendingPathComponent(filename)
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url)
        let item = UserStoredImage(id: id, filename: filename)
        images.insert(item, at: 0)
        save()
    }

    func removeImage(_ image: UserStoredImage) {
        let url = docsDir.appendingPathComponent(image.filename)
        try? FileManager.default.removeItem(at: url)
        images.removeAll { $0.id == image.id }
        save()
    }

    func localURL(for image: UserStoredImage) -> URL {
        docsDir.appendingPathComponent(image.filename)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([UserStoredImage].self, from: data)
        else { return }
        // Sadece dosyası hâlâ var olanları tut
        images = decoded.filter {
            FileManager.default.fileExists(atPath: docsDir.appendingPathComponent($0.filename).path)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(images) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

struct UserStoredImage: Identifiable, Codable {
    let id: String
    let filename: String
}
