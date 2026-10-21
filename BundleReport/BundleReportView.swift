import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BundleReportView: View {
    @EnvironmentObject private var catalog: AppCatalog
    @AppStorage("showUtilityApps") private var showUtilityApps = false
    @AppStorage("showAppleDefaultApps") private var showAppleDefaultApps = true
    @AppStorage("showPersonalApps") private var showPersonalApps = true
    @State private var searchText = ""
    @State private var selection: InstalledApp?

    private var filteredApps: [InstalledApp] {
        let userFacingApps = catalog.apps.filter { app in
            (showUtilityApps || !isUtilityApp(app)) &&
            (showAppleDefaultApps || !isAppleDefaultApp(app)) &&
            (showPersonalApps || !isPersonalApp(app))
        }

        guard !searchText.isEmpty else { return userFacingApps }
        return userFacingApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredApps, selection: $selection) { app in
                AppRow(app: app).tag(app)
            }
            .overlay {
                if catalog.isScanning && catalog.apps.isEmpty {
                    ProgressView("Finding applications…")
                } else if filteredApps.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(
                text: $searchText,
                placement: .sidebar,
                prompt: "Search applications or identifiers"
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let selection {
                DetailView(app: selection)
            } else {
                ContentUnavailableView(
                    "Choose an Application",
                    systemImage: "shippingbox",
                    description: Text("Select an installed app to inspect its bundle, signing, and related files.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ControlGroup {
                    Button { catalog.refresh() } label: {
                        Label("Refresh Applications", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh installed applications and the selected app's details")
                    .disabled(catalog.isScanning)
                }
            }

            ToolbarItem(placement: .automatic) {
                ControlGroup {
                    Button {
                        guard let app = selection else { return }
                        exportIcon(for: app)
                    } label: {
                        Label("Export Icon…", systemImage: "square.and.arrow.down")
                    }
                    .help("Export the app's icon as a PNG file")
                    .disabled(selection == nil)

                    Button {
                        guard let app = selection else { return }
                        NSWorkspace.shared.activateFileViewerSelecting([app.url])
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .help("Reveal in Finder")
                    .disabled(selection == nil)

                    Button {
                        guard let app = selection else { return }
                        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                    }
                    .help("Open application")
                    .disabled(selection == nil)
                }
            }

            ToolbarItem(placement: .automatic) {
                ControlGroup {
                    Button {
                        showUtilityApps.toggle()
                    } label: {
                        Label("Utility Apps", systemImage: showUtilityApps ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                    }
                    .help(showUtilityApps ? "Hide Utility Apps" : "Show Utility Apps")
                    .symbolRenderingMode(.monochrome)

                    Button {
                        showAppleDefaultApps.toggle()
                    } label: {
                        Label("Default Apple Apps", systemImage: "apple.logo")
                    }
                    .help(showAppleDefaultApps ? "Hide Default Apple Apps" : "Show Default Apple Apps")

                    Button {
                        showPersonalApps.toggle()
                    } label: {
                        Label("Apps in Your Applications Folder", systemImage: showPersonalApps ? "person.crop.circle.fill" : "person.crop.circle")
                    }
                    .help(showPersonalApps ? "Hide Apps in Your Applications Folder" : "Show Apps in Your Applications Folder")
                }
            }
        }
        .onChange(of: catalog.apps) { _, apps in
            if let selectedURL = selection?.url {
                selection = apps.first { $0.url == selectedURL }
            } else if let first = filteredApps.first {
                selection = first
            }
        }
    }

    private func isUtilityApp(_ app: InstalledApp) -> Bool {
        let path = app.url.standardized.path
        return path.contains("/Applications/Utilities/") ||
            path.contains("/System/Applications/Utilities/")
    }

    private func isAppleDefaultApp(_ app: InstalledApp) -> Bool {
        app.url.standardized.path.hasPrefix("/System/Applications/")
    }

    private func isPersonalApp(_ app: InstalledApp) -> Bool {
        app.url.standardized.path.hasPrefix("\(NSHomeDirectory())/Applications/")
    }

    private func exportIcon(for app: InstalledApp) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export App Icon"
        savePanel.nameFieldStringValue = "\(app.name).png"
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        do {
            let image = app.iconFileURL.flatMap { NSImage(contentsOf: $0) }
                ?? NSWorkspace.shared.icon(forFile: app.url.path)
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(
                    domain: "BundleReport",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "The app icon could not be converted to PNG."]
                )
            }
            try pngData.write(to: destinationURL)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).lineLimit(1)
                Text(app.bundleIdentifier ?? "No bundle identifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DetailView: View {
    let app: InstalledApp
    @State private var signingInfo: CodeSigningInfo?
    @State private var isLoadingSigningInfo = false
    @State private var appSizeOnDisk: Int64?
    @State private var iconFileSizeOnDisk: Int64?
    @State private var isCalculatingSizes = false
    @State private var copiedField: String?
    @AppStorage(DetailFieldPreference.version) private var showVersion = true
    @AppStorage(DetailFieldPreference.bundleIdentifier) private var showBundleIdentifier = true
    @AppStorage(DetailFieldPreference.appPath) private var showAppPath = true
    @AppStorage(DetailFieldPreference.appIconPath) private var showAppIconPath = true
    @AppStorage(DetailFieldPreference.relatedFiles) private var showRelatedFiles = true
    @AppStorage(DetailFieldPreference.codeRequirement) private var showCodeRequirement = true
    @AppStorage(DetailFieldPreference.signingIdentity) private var showSigningIdentity = true
    @AppStorage(DetailFieldPreference.teamIdentifier) private var showTeamIdentifier = true

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AppIdentityCard(
                    app: app,
                    sizeOnDisk: appSizeOnDisk,
                    isCalculatingSize: isCalculatingSizes
                )

                VStack(spacing: 14) {
                    if showVersion {
                        DetailField(
                            title: "Version",
                            value: app.versionDescription,
                            unavailableMessage: "This application does not declare a version.",
                            fieldID: "version",
                            copiedField: $copiedField
                        )
                    }

                    if showBundleIdentifier {
                        DetailField(
                            title: "Bundle Identifier",
                            value: app.bundleIdentifier,
                            unavailableMessage: "This application does not declare a bundle identifier.",
                            fieldID: "bundleIdentifier",
                            copiedField: $copiedField
                        )
                    }

                    if showAppPath {
                        DetailField(
                            title: "App Path",
                            value: app.url.path,
                            unavailableMessage: "The application path is unavailable.",
                            fieldID: "appPath",
                            sizeOnDisk: appSizeOnDisk,
                            isCalculatingSize: isCalculatingSizes,
                            revealURL: app.url,
                            copiedField: $copiedField
                        )
                    }

                    if showAppIconPath {
                        DetailField(
                            title: "App Icon Path",
                            value: app.iconFileURL?.path,
                            unavailableMessage: "This application does not provide a standalone icon file.",
                            fieldID: "appIconPath",
                            sizeOnDisk: iconFileSizeOnDisk,
                            isCalculatingSize: isCalculatingSizes && app.iconFileURL != nil,
                            copiedField: $copiedField
                        )
                    }

                    if isLoadingSigningInfo && hasVisibleSigningFields {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading code signature…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        if showCodeRequirement {
                            DetailField(
                                title: "Code Requirement",
                                value: signingInfo?.requirement,
                                unavailableMessage: "No designated code requirement is available.",
                                fieldID: "codeRequirement",
                                copiedField: $copiedField
                            )
                        }

                        if showSigningIdentity {
                            DetailField(
                                title: "Signing Identity",
                                value: signingInfo?.signingIdentity,
                                unavailableMessage: "No signing identity is available.",
                                fieldID: "signingIdentity",
                                copiedField: $copiedField
                            )
                        }

                        if showTeamIdentifier {
                            DetailField(
                                title: "Team ID",
                                value: signingInfo?.teamIdentifier,
                                unavailableMessage: "No Team ID is available.",
                                fieldID: "teamIdentifier",
                                copiedField: $copiedField
                            )
                        }
                    }

                    if showRelatedFiles {
                        RelatedFilesSection(app: app)
                    }
                }
                .frame(maxWidth: 596)

            }
            .padding(28)
        }
        .task(id: app) {
            copiedField = nil
            isLoadingSigningInfo = true
            signingInfo = nil
            let result = await Task.detached(priority: .userInitiated) {
                CodeSigningInfo.read(from: app.url)
            }.value
            guard !Task.isCancelled else { return }
            signingInfo = result
            isLoadingSigningInfo = false
        }
        .task(id: app) {
            isCalculatingSizes = true
            appSizeOnDisk = nil
            iconFileSizeOnDisk = nil
            let sizes = await Task.detached(priority: .utility) {
                (
                    AppCatalog.appSize(at: app.url),
                    app.iconFileURL.flatMap { AppCatalog.appSize(at: $0) }
                )
            }.value
            guard !Task.isCancelled else { return }
            appSizeOnDisk = sizes.0
            iconFileSizeOnDisk = sizes.1
            isCalculatingSizes = false
        }
    }

    private var hasVisibleSigningFields: Bool {
        showCodeRequirement || showSigningIdentity || showTeamIdentifier
    }

}

private struct RelatedFilesSection: View {
    let app: InstalledApp
    @State private var relatedFiles = [RelatedFile]()
    @State private var isSearching = false
    @State private var copiedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Related Files")
                    .font(.headline)
                Spacer()
                Text(sectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Searching common app-data locations…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                } else if relatedFiles.isEmpty {
                    Text(app.bundleIdentifier == nil
                        ? "A bundle identifier is required to find related files."
                        : "No matching files were found in the common app-data locations.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(Array(relatedFiles.enumerated()), id: \.element.id) { index, relatedFile in
                        RelatedFileRow(relatedFile: relatedFile, copiedURL: $copiedURL)
                            .padding(14)

                        if index < relatedFiles.count - 1 {
                            Divider()
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .task(id: app) {
            await findRelatedFiles()
        }
    }

    private var sectionStatus: String {
        if isSearching { return "Searching…" }
        return relatedFiles.isEmpty ? "None found" : "\(relatedFiles.count) found"
    }

    private func findRelatedFiles() async {
        isSearching = true
        relatedFiles = []
        copiedURL = nil

        let results = await Task.detached(priority: .utility) {
            RelatedFileFinder.discover(for: app)
        }.value
        guard !Task.isCancelled else { return }
        relatedFiles = results
        isSearching = false
    }
}

private struct RelatedFileRow: View {
    let relatedFile: RelatedFile
    @Binding var copiedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(relatedFile.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedSize(relatedFile.sizeOnDisk))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([relatedFile.url])
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(relatedFile.url.path, forType: .string)
                    copiedURL = relatedFile.url
                } label: {
                    Label(
                        copiedURL == relatedFile.url ? "Copied" : "Copy",
                        systemImage: copiedURL == relatedFile.url ? "checkmark" : "doc.on.doc"
                    )
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

            Text(relatedFile.url.path)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formattedSize(_ size: Int64?) -> String {
        guard let size else { return "Unavailable" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

private struct AppIdentityCard: View {
    let app: InstalledApp
    let sizeOnDisk: Int64?
    let isCalculatingSize: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 170), alignment: .leading)
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 80, height: 80)
                .shadow(radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 14) {
                Text(app.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    MetadataItem(title: "Architecture", value: app.architectures ?? "Unknown")
                    MetadataItem(title: "Minimum macOS", value: app.minimumOSVersion.map { "macOS \($0)" } ?? "Not declared")
                    MetadataItem(title: "Source", value: app.sourceDescription)
                    MetadataItem(title: "Quarantine", value: app.isQuarantined ? "Present" : "Cleared")
                    MetadataItem(title: "Installed", value: formatted(app.installationDate))
                    MetadataItem(title: "Modified", value: formatted(app.modificationDate))
                    MetadataItem(title: "Size", value: sizeDescription)
                }

                if let copyright = app.copyright, !copyright.isEmpty {
                    MetadataItem(title: "Copyright", value: copyright)
                }
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "Unavailable" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedSize(_ size: Int64?) -> String {
        guard let size else { return "Unavailable" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var sizeDescription: String {
        isCalculatingSize ? "Calculating…" : formattedSize(sizeOnDisk)
    }
}

private struct MetadataItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DetailField: View {
    let title: String
    let value: String?
    let unavailableMessage: String
    let fieldID: String
    let sizeOnDisk: Int64?
    let isCalculatingSize: Bool
    let revealURL: URL?
    @Binding var copiedField: String?

    init(
        title: String,
        value: String?,
        unavailableMessage: String,
        fieldID: String,
        sizeOnDisk: Int64? = nil,
        isCalculatingSize: Bool = false,
        revealURL: URL? = nil,
        copiedField: Binding<String?>
    ) {
        self.title = title
        self.value = value
        self.unavailableMessage = unavailableMessage
        self.fieldID = fieldID
        self.sizeOnDisk = sizeOnDisk
        self.isCalculatingSize = isCalculatingSize
        self.revealURL = revealURL
        _copiedField = copiedField
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if isCalculatingSize {
                    Text("Calculating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let sizeOnDisk {
                    Text(formattedSize(sizeOnDisk))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let revealURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([revealURL])
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
                copyButton
                    .buttonStyle(.bordered)
            }

            Text(value ?? unavailableMessage)
                .font(.body)
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copyValue() {
        guard let value else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedField = fieldID
    }

    private func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var copyButton: some View {
        Button { copyValue() } label: {
            Label(
                copiedField == fieldID ? "Copied" : "Copy",
                systemImage: copiedField == fieldID ? "checkmark" : "doc.on.doc"
            )
        }
        .controlSize(.small)
        .disabled(value == nil)
    }
}
