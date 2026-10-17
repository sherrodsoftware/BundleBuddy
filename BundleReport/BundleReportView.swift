import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BundleReportView: View {
    @EnvironmentObject private var catalog: AppCatalog
    @AppStorage("showUtilityApps") private var showUtilityApps = false
    @State private var searchText = ""
    @State private var selection: InstalledApp?
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    private var filteredApps: [InstalledApp] {
        let userFacingApps = showUtilityApps
            ? catalog.apps
            : catalog.apps.filter { !isUtilityApp($0) }

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
                if catalog.isScanning {
                    ProgressView("Finding applications…")
                } else if filteredApps.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search applications or identifiers")
            .navigationSplitViewColumnWidth(min: compact ? 240 : 280, ideal: compact ? 300 : 340)
        } detail: {
            if let selection {
                DetailView(app: selection)
            } else {
                ContentUnavailableView(
                    "Choose an Application",
                    systemImage: "shippingbox",
                    description: Text("Select an installed app to see its bundle identifier.")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button { catalog.refresh() } label: {
                    Label("Refresh Applications", systemImage: "arrow.clockwise")
                }
                .disabled(catalog.isScanning)
            }
            ToolbarItem {
                Toggle(isOn: $showUtilityApps) {
                    Label("Show Utility Apps", systemImage: "wrench.and.screwdriver")
                }
            }
        }
        .onChange(of: catalog.apps) { _, _ in
            if selection == nil, let first = filteredApps.first { selection = first }
        }
    }

    private func isUtilityApp(_ app: InstalledApp) -> Bool {
        let path = app.url.standardized.path
        return path.contains("/Applications/Utilities/") ||
            path.contains("/System/Applications/Utilities/")
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
    @State private var copiedField: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AppIdentityCard(app: app)

                VStack(spacing: 14) {
                    DetailField(
                        title: "Version",
                        value: app.versionDescription,
                        unavailableMessage: "This application does not declare a version.",
                        fieldID: "version",
                        copiedField: $copiedField
                    )

                    DetailField(
                        title: "Bundle Identifier",
                        value: app.bundleIdentifier,
                        unavailableMessage: "This application does not declare a bundle identifier.",
                        fieldID: "bundleIdentifier",
                        copiedField: $copiedField
                    )

                    DetailField(
                        title: "App Path",
                        value: app.url.path,
                        unavailableMessage: "The application path is unavailable.",
                        fieldID: "appPath",
                        copiedField: $copiedField
                    )

                    DetailField(
                        title: "App Icon Path",
                        value: app.iconFileURL?.path,
                        unavailableMessage: "This application does not provide a standalone icon file.",
                        fieldID: "appIconPath",
                        copiedField: $copiedField
                    )

                    if isLoadingSigningInfo {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading code signature…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        DetailField(
                            title: "Code Requirement",
                            value: signingInfo?.requirement,
                            unavailableMessage: "No designated code requirement is available.",
                            fieldID: "codeRequirement",
                            copiedField: $copiedField
                        )

                        DetailField(
                            title: "Signing Identity",
                            value: signingInfo?.signingIdentity,
                            unavailableMessage: "No signing identity is available.",
                            fieldID: "signingIdentity",
                            copiedField: $copiedField
                        )

                        DetailField(
                            title: "Team ID",
                            value: signingInfo?.teamIdentifier,
                            unavailableMessage: "No Team ID is available.",
                            fieldID: "teamIdentifier",
                            copiedField: $copiedField
                        )
                    }
                }
                .frame(maxWidth: 560)

                HStack {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([app.url])
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }

                    Button {
                        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                    }
                }

                Text(app.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            .padding(28)
        }
        .task(id: app.id) {
            isLoadingSigningInfo = true
            signingInfo = nil
            let result = await Task.detached(priority: .userInitiated) {
                CodeSigningInfo.read(from: app.url)
            }.value
            guard !Task.isCancelled else { return }
            signingInfo = result
            isLoadingSigningInfo = false
        }
    }
}

private struct AppIdentityCard: View {
    let app: InstalledApp

    private let columns = [
        GridItem(.adaptive(minimum: 170), alignment: .leading)
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(radius: 4, y: 2)

                Button {
                    exportIcon()
                } label: {
                    Label("Export Icon…", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
            }

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

    private func exportIcon() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export App Icon"
        savePanel.nameFieldStringValue = "\(app.name).png"
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: destinationURL.path) {
                try manager.removeItem(at: destinationURL)
            }
            let image = NSWorkspace.shared.icon(forFile: app.url.path)
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
    @Binding var copiedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                copyButton
                    .buttonStyle(.bordered)
            }

            Text(value ?? unavailableMessage)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func copyValue() {
        guard let value else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedField = fieldID
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
