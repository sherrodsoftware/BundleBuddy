# Changelog

## Bundle Report 2026.10.21

- Refresh now reflects updated app version numbers after an in-place app update.
- App names now match how they appear in Finder.
- Separated Version and Build into distinct fields, each copyable independently.
- Moved Export Icon, Reveal in Finder, and Open to the toolbar.
- Refined toolbar button layout into distinct grouped pods.
- Moved Related Files to the bottom of the detail view.
- Refined detail field appearance to better match macOS inspector conventions.
- Improved Settings window layout.

## Bundle Report 2026.10.20

- Added toolbar and View menu controls to show or hide Utilities apps, default Apple apps, and apps in your personal Applications folder.
- Utilities apps remain hidden by default for a more focused app list.
- Added Settings for choosing which detail fields appear below the app card.
- Refined toolbar behavior, search placement, refresh behavior, tooltips, and copy-state handling.
- Improved the default window layout and empty-state messaging.
- Updated Bundle Report's app icon presentation, including Finder appearance and PNG export.

## Bundle Report 2026.10.19 (Build 4)

- Removed the App Icon Path Reveal control, which could cause macOS to display an unintended App Management privacy prompt.
- Removed an unnecessary file-deletion step during app-icon PNG export.

## Bundle Report 2026.10.19

- Removed the menu-bar companion so Bundle Report is focused entirely on its main window.
- Increased the default window size and aligned the detail fields with the application summary card.
- Updated the empty state to reflect Bundle Report's expanded inspection features.

## Bundle Report 2026.10.18

- Added a richer application summary card with architecture, minimum macOS version, source, quarantine status, install and modification dates, and app size.
- Added copyable App Path and App Icon Path fields, including file sizes and Reveal controls.
- Added PNG app-icon export.
- Added Related Files discovery for common app data such as containers, application support, caches, preferences, logs, scripts, and saved state.
- Added Reveal and Copy controls for related files.
- Improved interface consistency and layout throughout the app.

## Bundle Report 2026.10.17

Bundle Buddy is now Bundle Report.

- App metadata overview: architecture, minimum macOS, install and modification dates, distribution source, and quarantine status.
- Copyable application and app-icon file paths.
- Export any application icon as a PNG.
- Updated product name and bundle identifier: `com.sherrodsoftware.BundleReport`.

## Bundle Buddy 2026.10.16

First public release.

- Browse apps in `/Applications`, `/System/Applications`, and `~/Applications`.
- Review an app's version and build number, bundle identifier, designated code requirement, signing identity, and Team ID.
- Copy any available value only when needed.
- Reveal or open the selected app from Bundle Buddy.
- Utility apps stay hidden by default, with an option to include them.
