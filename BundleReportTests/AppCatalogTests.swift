import Testing
import Foundation

// MARK: - MachOArchitectures

@Suite("MachOArchitectures")
struct MachOArchitecturesTests {

    // MARK: Thin binaries

    @Test func arm64LittleEndian() {
        // Thin Mach-O: magic 0xCEFAEDFE (little-endian), cputype = 0x0C000001 (arm64 LE)
        let magic: [UInt8] = [0xCE, 0xFA, 0xED, 0xFE]
        let cpuType: [UInt8] = [0x0C, 0x00, 0x00, 0x01] // arm64 in little-endian = 0x0100_000C
        let data = Data(magic + cpuType)
        #expect(MachOArchitectures.read(from: data) == "Apple silicon (arm64)")
    }

    @Test func x86_64LittleEndian() {
        // Thin Mach-O: magic 0xCEFAEDFE (little-endian), cputype = 0x07000001 (x86_64 LE)
        let magic: [UInt8] = [0xCE, 0xFA, 0xED, 0xFE]
        let cpuType: [UInt8] = [0x07, 0x00, 0x00, 0x01] // x86_64 in little-endian = 0x0100_0007
        let data = Data(magic + cpuType)
        #expect(MachOArchitectures.read(from: data) == "Intel (x86_64)")
    }

    @Test func tooShortReturnsNil() {
        #expect(MachOArchitectures.read(from: Data([0xCE, 0xFA])) == nil)
    }

    @Test func emptyDataReturnsNil() {
        #expect(MachOArchitectures.read(from: Data()) == nil)
    }

    @Test func unknownMagicReturnsNil() {
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(MachOArchitectures.read(from: data) == nil)
    }

    // MARK: Fat binaries

    @Test func fatBinaryUniversal() throws {
        // Fat Mach-O header: magic=0xCAFEBABE, nfat_arch=2, then two arch entries (20 bytes each)
        // arch[0]: cputype=0x0100_000C (arm64), arch[1]: cputype=0x0100_0007 (x86_64)
        var bytes = [UInt8]()
        // magic (big-endian)
        bytes += [0xCA, 0xFE, 0xBA, 0xBE]
        // nfat_arch = 2
        bytes += [0x00, 0x00, 0x00, 0x02]
        // arch entry 0: cputype arm64 (0x0100_000C), cpusubtype (4 bytes), offset (4), size (4), align (4)
        bytes += [0x01, 0x00, 0x00, 0x0C]
        bytes += [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        // arch entry 1: cputype x86_64 (0x0100_0007)
        bytes += [0x01, 0x00, 0x00, 0x07]
        bytes += [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let result = MachOArchitectures.read(from: Data(bytes))
        let parts = result?.components(separatedBy: ", ") ?? []
        #expect(parts.contains("Apple silicon (arm64)"))
        #expect(parts.contains("Intel (x86_64)"))
    }
}

// MARK: - InstalledApp helpers

@Suite("InstalledApp")
struct InstalledAppTests {

    private func makeApp(short: String?, build: String?) -> InstalledApp {
        InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleIdentifier: "com.test",
            shortVersion: short,
            buildVersion: build,
            architectures: nil,
            installationDate: nil,
            modificationDate: nil,
            minimumOSVersion: nil,
            isAppStoreApp: false,
            iconFileURL: nil,
            isQuarantined: false,
            copyright: nil
        )
    }

    @Test func versionDescriptionBothSame() {
        let app = makeApp(short: "1.0", build: "1.0")
        #expect(app.versionDescription == "1.0")
    }

    @Test func versionDescriptionDiffer() {
        let app = makeApp(short: "1.0", build: "42")
        #expect(app.versionDescription == "1.0 (42)")
    }

    @Test func versionDescriptionShortOnly() {
        let app = makeApp(short: "2.1", build: nil)
        #expect(app.versionDescription == "2.1")
    }

    @Test func versionDescriptionBuildOnly() {
        let app = makeApp(short: nil, build: "99")
        #expect(app.versionDescription == "99")
    }

    @Test func versionDescriptionNone() {
        let app = makeApp(short: nil, build: nil)
        #expect(app.versionDescription == nil)
    }

    @Test func sourceDescriptionAppStore() {
        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test", bundleIdentifier: nil, shortVersion: nil, buildVersion: nil,
            architectures: nil, installationDate: nil, modificationDate: nil,
            minimumOSVersion: nil, isAppStoreApp: true, iconFileURL: nil,
            isQuarantined: false, copyright: nil
        )
        #expect(app.sourceDescription == "Mac App Store")
    }

    @Test func sourceDescriptionOutsideStore() {
        let app = makeApp(short: nil, build: nil)
        #expect(app.sourceDescription == "Outside App Store")
    }
}

// MARK: - RelatedFileFinder

@Suite("RelatedFileFinder")
struct RelatedFileFinderTests {

    @Test func emptyBundleIDReturnsNothing() {
        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test", bundleIdentifier: nil, shortVersion: nil, buildVersion: nil,
            architectures: nil, installationDate: nil, modificationDate: nil,
            minimumOSVersion: nil, isAppStoreApp: false, iconFileURL: nil,
            isQuarantined: false, copyright: nil
        )
        #expect(RelatedFileFinder.discover(for: app).isEmpty)
    }

    @Test func blankBundleIDReturnsNothing() {
        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test", bundleIdentifier: "", shortVersion: nil, buildVersion: nil,
            architectures: nil, installationDate: nil, modificationDate: nil,
            minimumOSVersion: nil, isAppStoreApp: false, iconFileURL: nil,
            isQuarantined: false, copyright: nil
        )
        #expect(RelatedFileFinder.discover(for: app).isEmpty)
    }

    @Test func nonExistentBundleIDFindsNothing() {
        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleIdentifier: "com.bundlereport.tests.doesnotexist.ever.12345",
            shortVersion: nil, buildVersion: nil, architectures: nil,
            installationDate: nil, modificationDate: nil, minimumOSVersion: nil,
            isAppStoreApp: false, iconFileURL: nil, isQuarantined: false, copyright: nil
        )
        #expect(RelatedFileFinder.discover(for: app).isEmpty)
    }

    @Test func discoversPreferencesFile() throws {
        let bundleID = "com.bundlereport.tests.prefs.\(UUID().uuidString)"
        let prefsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(bundleID).plist")
        FileManager.default.createFile(atPath: prefsURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: prefsURL) }

        let app = InstalledApp(
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test", bundleIdentifier: bundleID, shortVersion: nil, buildVersion: nil,
            architectures: nil, installationDate: nil, modificationDate: nil,
            minimumOSVersion: nil, isAppStoreApp: false, iconFileURL: nil,
            isQuarantined: false, copyright: nil
        )
        let results = RelatedFileFinder.discover(for: app)
        #expect(results.contains { $0.reason == "Preference file" })
    }
}
