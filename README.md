<h1>
  <img src="docs/images/bundle-buddy-icon.png" alt="Bundle Buddy icon" width="48" />
  Bundle Buddy
</h1>

A small open-source macOS utility for quickly finding an installed app's bundle
identifier. Search the apps on your Mac, select one, and copy its identifier
only when you are ready—no Terminal required.

<p align="center">
  <img src="docs/images/bundle-buddy-main-window.png" alt="Bundle Buddy main window" width="720" />
</p>

## What it does

1. **Finds standard application bundles** in `/Applications`,
   `/System/Applications`, and `~/Applications`.
2. **Lists each app with its Finder icon, name, and bundle identifier** so the
   information is easy to identify at a glance.
3. **Searches by application name or bundle identifier**, making it quick to
   locate a specific app in a long list.
4. **Shows the selected identifier prominently** in a selectable,
   monospaced field for clear review before copying.
5. **Copies only on request.** Click **Copy Bundle Identifier** to place the
   identifier on the clipboard; selecting an app never overwrites it.
6. **Reveals or opens the selected app** directly from Bundle Buddy.
7. **Keeps Utility apps hidden by default** to keep the list focused. Turn on
   **Show Utility Apps** whenever you need to include them.
8. **Works from either the main window or the menu bar**, so the app is close
   at hand during policy, scripting, support, or device-management work.

## Requirements

- macOS 15 or later (Mac-only app — no iOS/iPadOS/visionOS target)

## Security

Please see [SECURITY.md](SECURITY.md) for responsible vulnerability reporting.

## License

Bundle Buddy is available under the [MIT License](LICENSE.md).
