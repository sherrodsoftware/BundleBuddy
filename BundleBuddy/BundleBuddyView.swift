import AppKit
import SwiftUI

struct BundleBuddyView: View {
    @EnvironmentObject private var catalog: AppCatalog
    @AppStorage("showUtilityApps") private var showUtilityApps = false
    @State private var searchText = ""
    @State private var selection: InstalledApp?
    @State private var copied = false
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
                DetailView(app: selection, copied: $copied, copy: copy)
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
        .onChange(of: selection) { _, _ in
            copied = false
        }
        .onChange(of: catalog.apps) { _, apps in
            if selection == nil, let first = apps.first { selection = first }
        }
    }

    private func copy(_ app: InstalledApp) {
        guard let identifier = app.bundleIdentifier else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(identifier, forType: .string)
        copied = true
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
    @Binding var copied: Bool
    let copy: (InstalledApp) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(radius: 5, y: 2)

            Text(app.name)
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Bundle Identifier")
                    .font(.headline)
                Text(app.bundleIdentifier ?? "This application does not declare a bundle identifier.")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: 460)

            HStack {
                Button { copy(app) } label: {
                    Label(copied ? "Copied" : "Copy Bundle Identifier", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.bundleIdentifier == nil)

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

            Spacer()
            Text(app.url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
        .padding(28)
    }
}
