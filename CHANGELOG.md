# Changelog

## Unreleased

## 2.2.0 - 2026-11-05

- Select light or dark status emails independently from the web UI. Reports show action items before system results, with an embedded project emblem and project links.
- Full-width web pages, project footer and six example reports in Settings.

- New web UI design: an app layout with a fixed sidebar (Dashboard, Containers & VMs, History, Settings), each page with its own URL; back/forward and bookmarks work. On phones a top bar and a tab bar at the bottom
- Dashboard shows only the state: four stat cards with the last 14 days as daily bars (updated systems, problems, runs) and a meter for pending updates, system status as a ring (up to date / updates available / problem / not checked), nodes with an action menu and the recent runs
- Settings collect everything else: schedule and time window, mail notification, program updates, appearance and an "About" card with version and links
- Removed the log page from the web UI (the log stays on the node)
- Light, dark or system theme (login page and Settings → Appearance), remembered in the browser
- Account menu in the sidebar (user, rights, sign out), status and next run below the navigation
- Run details show duration and nodes; history rows, attention items and recent runs link straight to the run
- Web UI reworked: one consistent stylesheet (tokens for colors, spacing, radius), nodes as a list
- Web UI: drawn SVG icons instead of unicode symbols, readable status labels ("Rolled back", "Checked" instead of ROLLBACK/TEST), mail subjects shown without emoji and prefixes
- Web UI: notices instead of `alert()` popups, loading placeholders, an explained empty history, visible keyboard focus, history rows open with Enter
- Web UI: works on phones (status panel, node list and guest table rearrange, the guest ID moves next to the name)
- Fixed: pressing Enter in the mail settings reloaded the page; history showed "selection" for runs that covered all automatic guests

## 2.1.0 - 2026-10-23

- Program updates: `pve-autoupdate update-check` looks for a new version on GitHub (at most every 12 hours, installs nothing); hint in the menu and in `status`
- Mail report: a new program version is mentioned in subject and report, and mailed once even when the notification is set to "only on problems"
- Web UI: banner when a new version is available, with "What's new" from this changelog, and an update button (Sys.Modify); "Program updates" section under Settings
- Web UI is optional: the setup wizard asks (step 6/6); without it everything runs in the terminal
- Web UI: settings page for the mail notification with test mail; new logo
- Web UI container: the Proxmox console logs in as root automatically (like the helper scripts), no password needed
- Installer: new banner and welcome page, clear box with the web UI address at the end, the mail address may stay empty
- Fixed: `ui-install` failed right after the wizard (umask); the one-liner failed with "Argument list too long" (now `bash <(curl ...)`)
- Removed the "review script content" question before installing

## 2.0.0 - 2026-10-21

- Helper-script style: one-line install, menu, spinner output, self-update with diff and SHA256
- English and German (menus, messages, mails)
- Works on any Proxmox VE node or cluster - nothing hard-coded
- Containers, Linux VMs (guest agent), Docker Compose, AdGuard Home, Forgejo, Uptime Kuma, Beszel, own services
- Snapshot -> update -> health check -> automatic rollback
- Rolling node reboots with quorum check and post-check mail
- Mail via postfix or own SMTP server
- Windows VMs: Windows Update via the QEMU guest agent with snapshot, reboot, health check and rollback
- Control interface for the coming web UI container: every run writes an event log, `run --only <ids,node:name>`, `--reboot`/`--no-reboot`, JSON commands `inventory`, `history`, `events`, `start`, `config set`, and `pair`/`remote` for an SSH key that may only run pve-autoupdate
- Update time window (`UPDATE_WINDOW=02:00-05:00`, may cross midnight): guests, nodes and reboots only inside it; asked in the wizard. Timer or web UI runs that hit a closed window show up in the history
- Web UI in its own small LXC, set up from the node with `pve-autoupdate ui-install` (wizard or flags): container, packages, TLS certificate, service user, SSH key limited to pve-autoupdate, pinned host key and API certificate (renewals confirmed over SSH), systemd service; `ui-update`, `ui-remove`, menu entry, offered at the end of the setup wizard. Proxmox login with realms and 2FA, overview of nodes, containers and VMs with last check and last update, start checks and updates (single, several, whole node with reboot), live view, history with details, node log, EN/DE, works on the phone. Python standard library only, TLS, pinned API certificate, CSRF protection, login throttling, read-only accounts (Sys.Audit) vs. Sys.Modify
- kaimazon.de look: amber truecolor terminal output, dark whiptail theme (opt out with `PVE_AUTOUPDATE_THEME=classic` or `NO_COLOR=1`), branded mail report
- Support via Liberapay

## 1.x

- Private predecessor (`fleet-update` / `standalone-update`) for a single homelab
