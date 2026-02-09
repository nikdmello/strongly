import Foundation

enum PersistenceError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case fileSystemError
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to save data"
        case .decodingFailed: return "Failed to load data"
        case .fileSystemError: return "Storage error"
        case .corruptedData: return "Data corrupted"
        }
    }
}

@MainActor
protocol PersistenceService {
    func save<T: Codable>(_ data: T, key: String) async throws
    func load<T: Codable>(key: String, as type: T.Type) async throws -> T?
    func delete(key: String) async throws
}

final class FileSystemPersistence: PersistenceService, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    nonisolated init() {}

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @MainActor
    func save<T: Codable>(_ data: T, key: String) async throws {
        let url = documentsDirectory.appendingPathComponent("\(key).json")

        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.encodingFailed
        }
    }

    @MainActor
    func load<T: Codable>(key: String, as type: T.Type) async throws -> T? {
        let url = documentsDirectory.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed
        }
    }

    @MainActor
    func delete(key: String) async throws {
        let url = documentsDirectory.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw PersistenceError.fileSystemError
        }
    }
}
