import SwiftUI

@main
struct BundleReportApp: App {
    @StateObject private var catalog = AppCatalog()
    @AppStorage("showUtilityApps") private var showUtilityApps = false
    @AppStorage("showAppleDefaultApps") private var showAppleDefaultApps = true
    @AppStorage("showPersonalApps") private var showPersonalApps = true

    var body: some Scene {
        WindowGroup {
            BundleReportView()
                .environmentObject(catalog)
                .frame(minWidth: 940, minHeight: 620)
        }
        .defaultSize(width: 1_060, height: 720)

        Settings {
            BundleReportSettingsView()
        }

        .commands {
            SidebarCommands()

            CommandGroup(after: .sidebar) {
                Divider()

                Button("Refresh Applications") {
                    catalog.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(catalog.isScanning)

                Button(showUtilityApps ? "Hide Utilities Apps" : "Show Utilities Apps") {
                    showUtilityApps.toggle()
                }

                Button(showAppleDefaultApps ? "Hide Default Apple Apps" : "Show Default Apple Apps") {
                    showAppleDefaultApps.toggle()
                }

                Button(showPersonalApps ? "Hide Apps in Your Applications Folder" : "Show Apps in Your Applications Folder") {
                    showPersonalApps.toggle()
                }
            }
        }
    }
}

enum DetailFieldPreference {
    static let version = "showVersionField"
    static let build = "showBuildField"
    static let bundleIdentifier = "showBundleIdentifierField"
    static let appPath = "showAppPathField"
    static let appIconPath = "showAppIconPathField"
    static let relatedFiles = "showRelatedFilesField"
    static let codeRequirement = "showCodeRequirementField"
    static let signingIdentity = "showSigningIdentityField"
    static let teamIdentifier = "showTeamIdentifierField"
}

private struct BundleReportSettingsView: View {
    @AppStorage(DetailFieldPreference.version) private var showVersion = true
    @AppStorage(DetailFieldPreference.build) private var showBuild = true
    @AppStorage(DetailFieldPreference.bundleIdentifier) private var showBundleIdentifier = true
    @AppStorage(DetailFieldPreference.appPath) private var showAppPath = true
    @AppStorage(DetailFieldPreference.appIconPath) private var showAppIconPath = true
    @AppStorage(DetailFieldPreference.relatedFiles) private var showRelatedFiles = true
    @AppStorage(DetailFieldPreference.codeRequirement) private var showCodeRequirement = true
    @AppStorage(DetailFieldPreference.signingIdentity) private var showSigningIdentity = true
    @AppStorage(DetailFieldPreference.teamIdentifier) private var showTeamIdentifier = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Version", isOn: $showVersion)
            Toggle("Build", isOn: $showBuild)
            Toggle("Bundle Identifier", isOn: $showBundleIdentifier)
            Toggle("App Path", isOn: $showAppPath)
            Toggle("App Icon Path", isOn: $showAppIconPath)
            Toggle("Code Requirement", isOn: $showCodeRequirement)
            Toggle("Signing Identity", isOn: $showSigningIdentity)
            Toggle("Team ID", isOn: $showTeamIdentifier)
            Toggle("Related Files", isOn: $showRelatedFiles)
        }
        .toggleStyle(.checkbox)
        .padding(24)
        .frame(minWidth: 300)
    }
}
