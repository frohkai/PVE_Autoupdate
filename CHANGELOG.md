# Changelog

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
