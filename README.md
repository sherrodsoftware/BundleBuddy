<h1>
  <img src="docs/images/bundle-buddy-icon-2026.10.16.png" alt="Bundle Report icon" width="48" />
  Bundle Report
</h1>

A small open-source macOS utility for quickly inspecting an installed app's
identity and code-signing details. Search the apps on your Mac, then review
and copy its version, bundle identifier, designated code requirement, signing
identity, and Team ID—no Terminal required.

<p align="center">
  <img src="docs/images/bundle-buddy-main-window.png" alt="Bundle Report main window" width="720" />
</p>

## What it does

1. **Finds standard application bundles** in `/Applications`,
   `/System/Applications`, and `~/Applications`.
2. **Lists each app with its Finder icon, name, and bundle identifier** so the
   information is easy to identify at a glance.
3. **Searches by application name or bundle identifier**, making it quick to
   locate a specific app in a long list.
4. **Shows the selected app's version and build number** in a selectable,
   monospaced field.
5. **Reads the designated code requirement, signing identity, and Team ID**
   directly from macOS's code-signing services.
6. **Copies only on request.** Each available detail has its own Copy button;
   selecting an app never overwrites the clipboard.
7. **Reveals or opens the selected app** directly from Bundle Report.
8. **Keeps Utility apps hidden by default** to keep the list focused. Turn on
   **Show Utility Apps** whenever you need to include them.
9. **Works from either the main window or the menu bar**, so the app is close
   at hand during policy, scripting, support, or device-management work.

## Requirements

- macOS 15 or later (Mac-only app — no iOS/iPadOS/visionOS target)

## Security

Please see [SECURITY.md](SECURITY.md) for responsible vulnerability reporting.

## License

Bundle Report is available under the [MIT License](LICENSE.md).
