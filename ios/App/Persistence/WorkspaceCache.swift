import Foundation
import CryptoKit
import Security
import TwilDiaryCore

struct CachedWorkspace: Codable {
    let schema: Int
    let scope: String
    let savedAt: Date
    let workspace: Workspace
}

@MainActor protocol WorkspaceCaching {
    func load(scope: String) -> CachedWorkspace?
    func save(_ workspace: Workspace, scope: String, at date: Date) throws
    func removeAll() throws
}

@MainActor final class MemoryWorkspaceCache: WorkspaceCaching {
    private var snapshot: CachedWorkspace?
    func load(scope: String) -> CachedWorkspace? { snapshot?.scope == scope ? snapshot : nil }
    func save(_ workspace: Workspace, scope: String, at date: Date) throws {
        snapshot = CachedWorkspace(schema: 1, scope: scope, savedAt: date, workspace: try workspace.validatingIdentities())
    }
    func removeAll() throws { snapshot = nil }
}

/// Encrypted owner-scoped snapshots. This is read caching, never an offline write queue.
@MainActor final class ProtectedWorkspaceCache: WorkspaceCaching {
    private let directory: URL
    private let testKey: SymmetricKey?
    init(directory: URL? = nil, key: SymmetricKey? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PrivateDiary", isDirectory: true)
        testKey = key
    }
    func load(scope: String) -> CachedWorkspace? {
        do {
            let url = file(scope)
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 && size <= 50 * 1_024 * 1_024 else { return nil }
            let encrypted = try Data(contentsOf: url)
            let plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: encrypted), using: key(create: false), authenticating: Data(scope.utf8))
            let value = try JSONDecoder().decode(CachedWorkspace.self, from: plaintext)
            guard value.schema == 1, value.scope == scope else { return nil }
            _ = try value.workspace.validatingIdentities()
            return value
        } catch { return nil }
    }
    func save(_ workspace: Workspace, scope: String, at date: Date) throws {
        let snapshot = CachedWorkspace(schema: 1, scope: scope, savedAt: date, workspace: try workspace.validatingIdentities())
        let plaintext = try JSONEncoder().encode(snapshot)
        guard let encrypted = try AES.GCM.seal(plaintext, using: key(create: true), authenticating: Data(scope.utf8)).combined else {
            throw APIError.message("Could not protect the offline diary.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var folder = directory; try folder.setResourceValues(values)
        try encrypted.write(to: file(scope), options: [.atomic, .completeFileProtection])
    }
    func removeAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    private func file(_ scope: String) -> URL {
        let digest = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".sealed")
    }
    private func key(create: Bool) throws -> SymmetricKey {
        if let testKey { return testKey }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.amit29533.TwilDiary.cache-key",
                                    kSecAttrAccount as String: "device-only"]
        var read = query; read[kSecReturnData as String] = true; read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound, create else { throw APIError.message("The protected offline diary is unavailable.") }
        let key = SymmetricKey(size: .bits256)
        var add = query
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw APIError.message("Could not protect the offline diary.") }
        return key
    }
}

extension AccessCredential {
    /// A cache partition only. Claims never authorize requests; the server validates Access.
    var cacheScope: String {
        let parts = token.split(separator: ".")
        var principal = token
        if parts.count == 3 {
            var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
            if let data = Data(base64Encoded: payload), let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let issuer = claims["iss"] as? String, let subject = claims["sub"] as? String, !issuer.isEmpty, !subject.isEmpty {
                principal = issuer + "\n" + subject
            }
        }
        return SHA256.hash(data: Data((AppConfiguration.backend.absoluteString + "\n" + principal).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
