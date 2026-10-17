import AppKit
import Security
import SwiftUI

struct InstalledApp: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let shortVersion: String?
    let buildVersion: String?

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
                found[url] = InstalledApp(
                    url: url,
                    name: name,
                    bundleIdentifier: bundle.bundleIdentifier,
                    shortVersion: shortVersion,
                    buildVersion: buildVersion
                )
            }
        }

        return found.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
