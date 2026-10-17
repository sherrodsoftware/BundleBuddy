import AppKit
import Security
import SwiftUI

struct InstalledApp: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let shortVersion: String?
    let buildVersion: String?
    let architectures: String?
    let installationDate: Date?
    let modificationDate: Date?
    let minimumOSVersion: String?
    let isAppStoreApp: Bool
    let iconFileURL: URL?
    let isQuarantined: Bool
    let copyright: String?

    var id: URL { url }

    var versionDescription: String? {
        switch (shortVersion, buildVersion) {
        case let (shortVersion?, buildVersion?) where shortVersion != buildVersion:
            "\(shortVersion) (\(buildVersion))"
        case let (shortVersion?, _):
            shortVersion
        case let (_, buildVersion?):
            buildVersion
        default:
            nil
        }
    }

    var sourceDescription: String {
        isAppStoreApp ? "Mac App Store" : "Outside App Store"
    }
}

struct CodeSigningInfo: Sendable {
    let requirement: String?
    let signingIdentity: String?
    let teamIdentifier: String?

    static func read(from appURL: URL) -> CodeSigningInfo {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else {
            return CodeSigningInfo(requirement: nil, signingIdentity: nil, teamIdentifier: nil)
        }

        var requirement: SecRequirement?
        let requirementText: String?
        if SecCodeCopyDesignatedRequirement(staticCode, SecCSFlags(), &requirement) == errSecSuccess,
           let requirement {
            var text: CFString?
            requirementText = SecRequirementCopyString(requirement, SecCSFlags(), &text) == errSecSuccess
                ? text as String?
                : nil
        } else {
            requirementText = nil
        }

        var signingDictionary: CFDictionary?
        let signingInfo = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingDictionary
        ) == errSecSuccess
            ? signingDictionary as? [CFString: Any]
            : nil
        let teamIdentifier = signingInfo?[kSecCodeInfoTeamIdentifier] as? String
        let certificates = signingInfo?[kSecCodeInfoCertificates] as? [SecCertificate]
        let signingIdentity = certificates?.first.flatMap { SecCertificateCopySubjectSummary($0) as String? }

        return CodeSigningInfo(
            requirement: requirementText,
            signingIdentity: signingIdentity,
            teamIdentifier: teamIdentifier
        )
    }
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isScanning = false

    init() {
        refresh()
    }

    func refresh() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = Self.discoverApps()

            Task { @MainActor in
                guard let self else { return }
                self.apps = apps
                self.isScanning = false
            }
        }
    }

    nonisolated private static func discoverApps() -> [InstalledApp] {
        let locations = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
        let manager = FileManager.default
        var found = [URL: InstalledApp]()

        for path in locations {
            let root = URL(fileURLWithPath: path, isDirectory: true)
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url) else { continue }
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                found[url] = InstalledApp(
                    url: url,
                    name: name,
                    bundleIdentifier: bundle.bundleIdentifier,
                    shortVersion: shortVersion,
                    buildVersion: buildVersion,
                    architectures: architectures(for: bundle),
                    installationDate: resourceValues?.creationDate,
                    modificationDate: resourceValues?.contentModificationDate,
                    minimumOSVersion: minimumOSVersion(for: bundle),
                    isAppStoreApp: manager.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path),
                    iconFileURL: iconFileURL(for: bundle),
                    isQuarantined: isQuarantined(url),
                    copyright: bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
                )
            }
        }

        return found.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func minimumOSVersion(for bundle: Bundle) -> String? {
        if let version = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String {
            return version
        }

        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = ""
        #endif
        let versions = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersionByArchitecture") as? [String: String]
        return versions?[architecture]
    }

    nonisolated private static func architectures(for bundle: Bundle) -> String? {
        guard let executableURL = bundle.executableURL,
              let data = try? Data(contentsOf: executableURL, options: .mappedIfSafe) else {
            return nil
        }

        return MachOArchitectures.read(from: data)
    }

    nonisolated private static func iconFileURL(for bundle: Bundle) -> URL? {
        guard let resourcesURL = bundle.resourceURL else { return nil }
        let manager = FileManager.default

        if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           !iconFile.isEmpty {
            let filename = iconFile.hasSuffix(".icns") ? iconFile : "\(iconFile).icns"
            let iconURL = resourcesURL.appendingPathComponent(filename)
            if manager.fileExists(atPath: iconURL.path) {
                return iconURL
            }
        }

        guard let resourceFiles = try? manager.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return resourceFiles
            .filter { $0.pathExtension.localizedCaseInsensitiveCompare("icns") == .orderedSame }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .first
    }

    nonisolated private static func isQuarantined(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.quarantinePropertiesKey]) else {
            return false
        }
        return values.quarantineProperties != nil
    }
}

private enum MachOArchitectures {
    private static let fatMagic: UInt32 = 0xCAFE_BABE
    private static let fatCigam: UInt32 = 0xBEBA_FECA
    private static let fatMagic64: UInt32 = 0xCAFE_BABF
    private static let fatCigam64: UInt32 = 0xBFBA_FECA

    static func read(from data: Data) -> String? {
        guard let magic = uint32(in: data, at: 0, littleEndian: false) else { return nil }

        switch magic {
        case fatMagic:
            return fatArchitectures(in: data, littleEndian: false, is64Bit: false)
        case fatMagic64:
            return fatArchitectures(in: data, littleEndian: false, is64Bit: true)
        case fatCigam:
            return fatArchitectures(in: data, littleEndian: true, is64Bit: false)
        case fatCigam64:
            return fatArchitectures(in: data, littleEndian: true, is64Bit: true)
        case 0xCEFA_EDFE, 0xCFFA_EDFE:
            return architectureName(for: uint32(in: data, at: 4, littleEndian: true))
        case 0xFEED_FACE, 0xFEED_FACF:
            return architectureName(for: uint32(in: data, at: 4, littleEndian: false))
        default:
            return nil
        }
    }

    private static func fatArchitectures(in data: Data, littleEndian: Bool, is64Bit: Bool) -> String? {
        guard let count = uint32(in: data, at: 4, littleEndian: littleEndian) else { return nil }
        let architectureSize = is64Bit ? 32 : 20
        let availableArchitectureCount = max(0, (data.count - 8) / architectureSize)
        var names = [String]()

        for index in 0..<min(Int(count), availableArchitectureCount) {
            guard let name = architectureName(for: uint32(in: data, at: 8 + index * architectureSize, littleEndian: littleEndian)) else {
                continue
            }
            if !names.contains(name) {
                names.append(name)
            }
        }

        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    private static func architectureName(for cpuType: UInt32?) -> String? {
        guard let cpuType else { return nil }
        switch cpuType {
        case 0x0100_000C: return "Apple silicon (arm64)"
        case 0x0100_0007: return "Intel (x86_64)"
        case 0x0000_000C: return "ARM"
        case 0x0000_0007: return "Intel (x86)"
        default: return nil
        }
    }

    private static func uint32(in data: Data, at offset: Int, littleEndian: Bool) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        let value = data[offset..<(offset + 4)].reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
        return littleEndian ? value.byteSwapped : value
    }
}
