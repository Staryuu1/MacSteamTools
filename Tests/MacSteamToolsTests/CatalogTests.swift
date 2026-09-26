import Foundation
import CryptoKit

struct CatalogTests {
    static func expectFailure(_ body: () async throws -> Void) async {
        do { try await body() } catch { return }
        fatalError("Expected async failure")
    }
    static func run() async throws {
        let searchData = Data(#"{"code":0,"data":{"results":[{"id":"400","name":"Portal","image":null},{"id":"400","name":"Duplicate","image":null},{"id":"../bad","name":"Invalid","image":null}]}}"#.utf8)
        let service = Catalog(fetch: { request in
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "Portal & test")
            return (searchData, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let games = try await service.search(" Portal & test ")
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "400")
        print("PASS: search decoding, escaping, deduplication")
        for status in [404, 403, 429, 500] {
            let unavailable = Catalog(fetch: { request in
                (Data("error".utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            })
            await expectFailure { _ = try await unavailable.lua(for: games[0]) }
        }
        print("PASS: HTTP failure handling")
        XCTAssertThrowsError(try Catalog.validateLua(Data("addappid(4000)".utf8), appID: "400"))
        XCTAssertThrowsError(try Catalog.validateLua(Data("<html>404</html>".utf8), appID: "400"))
        try Catalog.validateLua(Data("-- example\n addappid ( 400, 1)".utf8), appID: "400")
        print("PASS: Lua identity and content validation")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in Installer.dlls { try Data("MZ-fixture".utf8).write(to: root.appendingPathComponent(name)) }
        try Data("unused".utf8).write(to: root.appendingPathComponent("ignored.txt"))
        let zip = root.appendingPathComponent("fixture.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = root
        process.arguments = ["-q", zip.path] + Installer.dlls + ["ignored.txt"]
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let zipData = try Data(contentsOf: zip)
        let releaseJSON: [String: Any] = ["tag_name": "v-test", "assets": [[
            "name": "OpenSteamTool-v-test-Release.zip",
            "browser_download_url": "https://github.com/madoiscool/BetterSteamTools/releases/download/v-test/package.zip",
            "size": zipData.count,
            "digest": "sha256:" + SHA256.hash(data: zipData).map { String(format: "%02x", $0) }.joined()
        ]]]
        let release = try JSONDecoder().decode(GitHubRelease.self, from: JSONSerialization.data(withJSONObject: releaseJSON))
        let download = Catalog(fetch: { request in
            (zipData, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let output = root.appendingPathComponent("extracted")
        try await download.downloadModules(release, to: output)
        for name in Installer.dlls { XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(name)), Data("MZ-fixture".utf8)) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appendingPathComponent("ignored.txt").path))
        print("PASS: release checksum and selective ZIP extraction")
        let corrupted = Catalog(fetch: { request in
            var data = zipData; data[0] ^= 1
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        await expectFailure { try await corrupted.downloadModules(release, to: root.appendingPathComponent("bad")) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("bad/dwmapi.dll").path))
        print("PASS: checksum mismatch prevents extraction")
        let debugOnly = GitHubRelease(tag_name: "test", assets: [.init(name: "OpenSteamTool-test-Debug.zip", browser_download_url: Catalog.releasePage, size: 10, digest: nil)])
        XCTAssertThrowsError(try debugOnly.package())
        print("PASS: Debug releases excluded")
    }
}
