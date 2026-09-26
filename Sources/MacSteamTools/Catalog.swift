import Foundation
import CryptoKit

struct Game: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let image: URL?
}
struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        let size: Int
        let digest: String?
    }
    let tag_name: String
    let assets: [Asset]
    func package() throws -> Asset {
        let matches = assets.filter { $0.name.hasPrefix("OpenSteamTool-") && $0.name.hasSuffix("-Release.zip") }
        guard matches.count == 1, let asset = matches.first,
              asset.browser_download_url.scheme == "https",
              asset.browser_download_url.host == "github.com",
              asset.browser_download_url.path.hasPrefix("/madoiscool/BetterSteamTools/releases/download/"),
              asset.size > 0, asset.size <= 64 * 1024 * 1024 else {
            throw ToolError(message: "Paket Release BetterSteamTools tidak ditemukan atau format rilis berubah.")
        }
        return asset
    }
}

struct Catalog {
    static let releasePage = URL(string: "https://github.com/madoiscool/BetterSteamTools/releases")!
    static let manifestPage = URL(string: "https://github.com/steamtools-games/ManifestHub3")!
    // Keep the transport injectable for offline tests of HTTP failures and formats.
    var fetch: (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    func get(_ url: URL, limit: Int = 2 * 1024 * 1024) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("MacSteamTools/0.2", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ToolError(message: "Respons server tidak valid.") }
        switch http.statusCode {
        case 200: break
        case 404: throw ToolError(message: "File belum tersedia di sumber ini (404). Coba game lain atau coba lagi nanti.")
        case 403, 429: throw ToolError(message: "Batas akses server tercapai. Tunggu beberapa menit lalu coba lagi.")
        default: throw ToolError(message: "Server mengembalikan HTTP \(http.statusCode). Coba lagi nanti.")
        }
        guard !data.isEmpty, data.count <= limit else { throw ToolError(message: "Unduhan kosong atau melebihi batas ukuran.") }
        return data
    }
    func latestRelease() async throws -> GitHubRelease {
        let data = try await get(URL(string: "https://api.github.com/repos/madoiscool/BetterSteamTools/releases/latest")!)
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
    func search(_ query: String) async throws -> [Game] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var url = URLComponents(string: "https://steamtools.games/api/search")!
        url.queryItems = [URLQueryItem(name: "query", value: query)]
        let data = try await get(url.url!)
        struct Response: Decodable {
            struct Payload: Decodable { let results: [Game] }
            let code: Int
            let message: String?
            let data: Payload?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.code == 0, let payload = response.data else {
            throw ToolError(message: response.message ?? "Pencarian ManifestHub sedang tidak tersedia.")
        }
        var seen = Set<String>()
        return payload.results.filter { Self.validID($0.id) && seen.insert($0.id).inserted }
    }
    static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) } && UInt32(value).map { $0 > 0 } == true
    }
    func lua(for game: Game) async throws -> Data {
        guard Self.validID(game.id) else { throw ToolError(message: "App ID tidak valid.") }
        let url = URL(string: "https://raw.githubusercontent.com/steamtools-games/ManifestHub3/\(game.id)/\(game.id).lua")!
        let data = try await get(url)
        try Self.validateLua(data, appID: game.id)
        return data
    }
    static func validateLua(_ data: Data, appID: String) throws {
        guard validID(appID), data.count <= 2 * 1024 * 1024,
              let text = String(data: data, encoding: .utf8), !text.contains("\0"),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<"),
              text.range(of: "(?m)^\\s*addappid\\s*\\(\\s*\(appID)\\s*[,)]", options: .regularExpression) != nil else {
            throw ToolError(message: "Respons bukan Lua ManifestHub yang valid untuk App ID \(appID).")
        }
    }
    func downloadModules(_ release: GitHubRelease, to folder: URL) async throws {
        let asset = try release.package()
        let data = try await get(asset.browser_download_url, limit: 64 * 1024 * 1024)
        guard data.count == asset.size else { throw ToolError(message: "Ukuran paket tidak sesuai metadata GitHub.") }
        if let digest = asset.digest {
            let computed = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest.lowercased() == computed else { throw ToolError(message: "Checksum paket tidak sesuai GitHub. Instalasi dibatalkan.") }
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appendingPathComponent("release.zip")
        try data.write(to: zip, options: .atomic)
        try ModuleArchive.extract(zip, to: folder)
    }
}

// Read only the three expected entries, never extract arbitrary archive paths.
struct ModuleArchive {
    static func unzip(_ args: [String], limit: Int) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        var result = Data()
        while true {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            result.append(chunk)
            if result.count > limit {
                process.terminate()
                try? pipe.fileHandleForReading.close()
                throw ToolError(message: "Isi ZIP melebihi batas ukuran.")
            }
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ToolError(message: "Paket ZIP rusak atau tidak dapat dibaca.") }
        return result
    }
    static func extract(_ zip: URL, to folder: URL) throws {
        let listing = try unzip(["-Z1", zip.path], limit: 1024 * 1024)
        guard let text = String(data: listing, encoding: .utf8) else { throw ToolError(message: "Daftar isi ZIP tidak valid.") }
        let entries = text.components(separatedBy: .newlines)
        for name in Installer.dlls {
            // Current upstream release contains DLLs directly at archive root.
            let matches = entries.filter { $0.lowercased() == name.lowercased() }
            guard matches.count == 1 else { throw ToolError(message: "ZIP harus berisi tepat satu \(name) di root.") }
            let data = try unzip(["-p", zip.path, matches[0]], limit: 32 * 1024 * 1024)
            guard data.prefix(2) == Data([0x4d, 0x5a]) else { throw ToolError(message: "\(name) bukan DLL Windows.") }
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }
}
