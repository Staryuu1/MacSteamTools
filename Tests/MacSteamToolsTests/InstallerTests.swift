import Foundation

func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(rhs), got \(lhs)") }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTFail(_ message: String) { fatalError(message) }
func XCTAssertThrowsError<T>(_ body: @autoclosure () throws -> T) {
    do { _ = try body() } catch { return }
    fatalError("Expected an error")
}

final class InstallerTests {
    var root: URL!
    var target: Target!
    var source: URL!
    func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let prefix = root.appendingPathComponent("Bottle with spaces")
        let steam = prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam")
        source = root.appendingPathComponent("Extracted")
        try FileManager.default.createDirectory(at: steam, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        for path in ["cxbottle.conf", "system.reg", "user.reg", "drive_c/Program Files (x86)/Steam/steam.exe"] {
            try Data().write(to: prefix.appendingPathComponent(path))
        }
        for name in Installer.dlls { try Data("MZ-test".utf8).write(to: source.appendingPathComponent(name)) }
        target = Target(prefix: prefix, steam: steam, runtime: URL(fileURLWithPath: "/bin/echo"))
    }
    func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testInstallSetsOverridesBeforeCopiesAndBacksUp() throws {
        let destination = target.steam.appendingPathComponent("dwmapi.dll")
        try Data("old dll".utf8).write(to: destination)
        var adds = 0
        var values: [String: String] = [:]
        let installer = Installer { _, args in
            if args[1] == "add" {
                XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "old dll")
                XCTAssertEqual(args[8], "native,builtin")
                adds += 1
                values[args[4]] = args[8]
            }
            if args[1] == "query" && args.count > 3 { return CommandResult(status: 0, output: "value    REG_SZ    \(values[args[4]] ?? "builtin")\n") }
            return CommandResult(status: 0, output: "")
        }
        let backup = try installer.install(target: target, source: source)
        XCTAssertEqual(adds, 3)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "MZ-test")
        XCTAssertEqual(try String(contentsOf: backup.appendingPathComponent("0-dwmapi.dll"), encoding: .utf8), "old dll")
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.steam.appendingPathComponent("config/stplug-in").path))
    }
    func testMissingDLLDoesNotTouchRegistry() throws {
        try FileManager.default.removeItem(at: source.appendingPathComponent("xinput1_4.dll"))
        let installer = Installer { _, _ in XCTFail("Registry must not run"); return CommandResult(status: 0, output: "") }
        XCTAssertThrowsError(try installer.install(target: target, source: source))
    }
    func testRegistryFailureRestoresPriorValuesAndDoesNotCopy() throws {
        var commands: [[String]] = []
        let installer = Installer { _, args in
            commands.append(args)
            if args[1] == "query" && args.count > 3 { return CommandResult(status: 0, output: "value    REG_SZ    builtin\n") }
            if args[1] == "add" && args[4] == "xinput1_4" && args[8] == "native,builtin" { return CommandResult(status: 2, output: "failure") }
            return CommandResult(status: 0, output: "")
        }
        XCTAssertThrowsError(try installer.install(target: target, source: source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.steam.appendingPathComponent("dwmapi.dll").path))
        XCTAssertEqual(commands.filter { $0[1] == "add" && $0[8] == "builtin" }.count, 2)
    }
    func testRejectEscapingConfigSymlink() throws {
        try FileManager.default.createSymbolicLink(at: target.steam.appendingPathComponent("config"), withDestinationURL: source)
        let installer = Installer { _, _ in XCTFail("Must reject before registry"); return CommandResult(status: 0, output: "") }
        XCTAssertThrowsError(try installer.install(target: target, source: source))
    }
    func testCopyFailureRestoresFilesAndRemovesNewOverrides() throws {
        let destination = target.steam.appendingPathComponent("dwmapi.dll")
        try Data("original".utf8).write(to: destination)
        var deletes = 0
        var values: [String: String] = [:]
        let installer = Installer { _, args in
            if args[1] == "query" && args.count > 3 {
                if let value = values[args[4]] { return CommandResult(status: 0, output: "value REG_SZ \(value)") }
                return CommandResult(status: 1, output: "missing")
            }
            if args[1] == "add" { values[args[4]] = args[8] }
            if args[1] == "add" && args[4] == "OpenSteamTool" {
                try FileManager.default.removeItem(at: self.source.appendingPathComponent("OpenSteamTool.dll"))
            }
            if args[1] == "delete" { deletes += 1 }
            return CommandResult(status: 0, output: "")
        }
        XCTAssertThrowsError(try installer.install(target: target, source: source))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.steam.appendingPathComponent("xinput1_4.dll").path))
        XCTAssertEqual(deletes, 3)
    }
    func testReadbackMismatchPreventsCopy() throws {
        let installer = Installer { _, args in
            if args[1] == "query" && args.count > 3 { return CommandResult(status: 0, output: "value REG_SZ builtin") }
            return CommandResult(status: 0, output: "")
        }
        XCTAssertThrowsError(try installer.install(target: target, source: source))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.steam.appendingPathComponent("dwmapi.dll").path))
    }
    func testLuaOnlyInstallAndBackup() throws {
        let installer = Installer { _, _ in XCTFail("Lua must not change registry"); return CommandResult(status: 0, output: "") }
        let data = Data("addappid(400)\n".utf8)
        _ = try installer.installLua(target: target, appID: "400", data: data)
        let changed = Data("addappid(400)\n--new".utf8)
        let backup = try installer.installLua(target: target, appID: "400", data: changed)
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("400.lua")), data)
        XCTAssertEqual(try Data(contentsOf: target.steam.appendingPathComponent("config/stplug-in/400.lua")), changed)
        XCTAssertThrowsError(try installer.installLua(target: target, appID: "../bad", data: data))
        XCTAssertThrowsError(try installer.installLua(target: target, appID: "400", data: Data("<html>error</html>".utf8)))
    }
    func testCrossOverEnvironmentTargetsSelectedBottle() {
        XCTAssertEqual(target.environment()["CX_BOTTLE"], "Bottle with spaces")
        XCTAssertEqual(target.environment()["CX_BOTTLE_PATH"], root.path)
        XCTAssertEqual(target.environment()["WINEPREFIX"], target.prefix.path)
    }
}

@main struct TestRunner {
    static func main() async throws {
        let tests: [(String, (InstallerTests) throws -> Void)] = [
            ("install order and backup", { try $0.testInstallSetsOverridesBeforeCopiesAndBacksUp() }),
            ("missing DLL", { try $0.testMissingDLLDoesNotTouchRegistry() }),
            ("registry rollback", { try $0.testRegistryFailureRestoresPriorValuesAndDoesNotCopy() }),
            ("escaping symlink", { try $0.testRejectEscapingConfigSymlink() }),
            ("copy failure rollback", { try $0.testCopyFailureRestoresFilesAndRemovesNewOverrides() }),
            ("readback mismatch", { try $0.testReadbackMismatchPreventsCopy() }),
            ("Lua-only install and backup", { try $0.testLuaOnlyInstallAndBackup() }),
            ("bottle environment", { $0.testCrossOverEnvironmentTargetsSelectedBottle() })
        ]
        for (name, test) in tests {
            let fixture = InstallerTests()
            try fixture.setUpWithError()
            defer { try? fixture.tearDownWithError() }
            try test(fixture)
            print("PASS: \(name)")
        }
        try await CatalogTests.run()
        print("All installer and catalog tests passed.")
    }
}
