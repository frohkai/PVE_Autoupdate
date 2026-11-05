/* pve-autoupdate web UI - plain JavaScript, no libraries (works offline in the LAN) */
"use strict";

const AUTHOR = "Kai Frohwerk";
const WEBSITE = "https://kaimazon.de";
const REPO_URL = "https://github.com/frohkai/PVE_Autoupdate";
const DONATE_URL = "https://liberapay.com/Viollent_Tech/donate";
const hasDonate = () => DONATE_URL.startsWith("http") && !DONATE_URL.includes("__");

// ------------------------------------------------------------------ texts
const TXT = {
  en: {
    report_systems: "Systems", report_packages: "Installed packages", report_results: "System results", no_attention: "No action required.",
    mail_theme: "Mail colour scheme", mail_preview: "Mail preview", site_links: "My links", project_by: "A project by", sample_attention: "Needs attention", sample_success: "Successful run", sample_dryrun: "Dry run",
    upd_title: "New version {v} available", upd_installed: "installed: {v}", upd_whatsnew: "What's new", upd_now: "Update now",
    upd_check: "Check now", upd_section: "Program updates", upd_installed_l: "Installed version", upd_latest_l: "Newest version",
    upd_checked_l: "Last check", upd_none: "not checked yet", upd_uptodate: "Up to date.", upd_checking: "Checking GitHub ...",
    upd_unreach: "GitHub is not reachable - no check possible (private repository or no internet).",
    upd_confirm_t: "Install the update?", upd_confirm_p: "pve-autoupdate {v} is downloaded from GitHub and installed on the node. The web UI restarts during the update and this page reloads by itself afterwards - you may have to sign in again.",
    upd_running: "The update is running - this page reloads by itself in a moment ...", upd_failed: "The update could not be started",
    upd_hint_cli: "In the terminal: pve-autoupdate update-check / pve-autoupdate self-update. GitHub is asked at most every 12 hours; nothing is installed without you.",
    settings: "Settings", set_mail: "Notification by e-mail", set_mail_sub: "Get a report by mail after the updates ran.",
    set_notify: "When to send a mail", n_never: "Never", n_errors: "Only when something went wrong", n_changes: "On problems and when something was updated", n_always: "After every run",
    set_to: "Recipient", set_to_ph: "name@example.com (several separated by commas)",
    set_transport: "Sending", tr_system: "Proxmox mail system (postfix)", tr_smtp: "Own SMTP server (e.g. Gmail with app password)",
    set_from: "Sender (empty = automatic)", set_title: "Name in the subject",
    set_host: "SMTP server", set_port: "Port", set_sec: "Encryption", sec_starttls: "STARTTLS (usually port 587)", sec_ssl: "SSL/TLS (usually port 465)", sec_none: "none (port 25, LAN only)",
    set_user: "User name (empty = no login)", set_pass: "Password or app password", set_pass_kept: "saved - leave empty to keep it",
    set_save: "Save", set_save_test: "Save and send test mail", set_saved: "Saved.", sending: "Sending the test mail ...",
    set_test_ok: "Saved. The test mail was handed over - check your inbox.", set_test_fail: "Saved, but the test mail could not be sent:",
    set_err: "Could not save", need_to: "Please enter a valid e-mail address.", need_host: "Please enter the SMTP server.", need_port: "Please enter a port (1-65535).",
    mail_off_hint: "Mail notifications are off - you will not hear about failed updates.", mail_set_up: "Set up now",
    set_ro: "Your account can view, but not change settings (Sys.Modify needed).",
    login_title: "Sign in", login_sub: "with your Proxmox VE account", user: "User name", password: "Password",
    realm: "Realm", sign_in: "Sign in", code: "Two-factor code", code_hint: "Code from your authenticator app (or a recovery key)",
    verify: "Verify", bad_login: "Login failed - check user name, password and realm.", bad_code: "The code is not valid.",
    no_permission: "This account may not see the nodes (Sys.Audit needed).", too_many_attempts: "Too many failed attempts - please wait a few minutes.",
    expired: "That took too long - please sign in again.", node_down: "The Proxmox node does not answer",
    overview: "Overview", history: "History", logout: "Sign out", read_only: "read only",
    ro_banner: "Your account can view, but not start updates (Sys.Modify needed).",
    schedule: "Schedule", next_run: "Next run", last_run: "Last run", state: "Status",
    window_open: "update window open", window_closed: "outside the update window", no_window: "no time window",
    idle: "Ready", running: "Update running", reboot_pending: "Node reboot pending (post check follows)",
    never: "never", nodes: "Nodes", guests: "System", kind_ct: "Container (LXC)", kind_vm: "Virtual machine",
    check: "Check", update: "Update", update_reboot: "Update + reboot", check_all: "Check all", update_all: "Update all",
    online: "online", offline: "offline", last_update: "Last update", last_check: "Last check", none_yet: "nothing yet",
    search: "Search name or ID", all: "All", cts: "Containers", vms: "VMs", auto_only: "Automatic",
    selected: "selected", auto: "Automatic", auto_tip: "updated by the schedule", manual_tip: "only when you start it here",
    id: "ID", name: "Name", type: "Type", node: "Node", status: "Status", actions: "Actions", yes: "yes", no: "no",
    st_running: "running", st_stopped: "stopped", template: "template", ui_node: "The web UI talks to this node",
    no_guests: "No containers or VMs found.", no_match: "Nothing matches the filter.",
    run_check: "Check running", run_update: "Update running", run_done: "Finished", run_aborted: "Aborted",
    run_rebooting: "Nodes are rebooting - the post check follows after boot", run_window: "Nothing done - outside the update window", close: "Close", waiting: "Waiting for the first result ...",
    cancel: "Cancel", start: "Start", dismiss: "Dismiss",
    m_check_t: "Check for updates", m_check_p: "Only looks - nothing is installed or changed.",
    m_update_t: "Install updates now", m_update_p: "A snapshot is taken before every update. If the health check fails afterwards, the guest is rolled back automatically.",
    m_all: "Everything that is set to automatic", allow_reboot: "Reboot if an update needs it",
    allow_reboot_node: "Reboot the node if needed (cluster: one after another, quorum is checked; guests on it are briefly offline)",
    outside_window: "It is outside the update window ({w}).", force_window: "Run anyway",
    started: "Started", already_running: "An update is already running.", failed_start: "Could not start",
    h_when: "Started", h_kind: "Kind", h_target: "Targets", h_result: "Result", h_by: "By",
    k_update: "Update", k_check: "Check", by_ui: "web UI", by_cli: "schedule / console", all_selected: "all automatic",
    no_history: "No runs yet.", no_history_p: "Runs show up here once the schedule has run or you start a check on the overview.", go_overview: "Go to overview",
    back: "Back", results: "Results", events: "Log of this run", refresh: "Refresh", no_results: "No results in this run.",
    pkgs: "{n} pkg", post: "Post check",
    s_running: "Running", s_ok: "OK", s_fail: "Errors", s_aborted: "Aborted", s_rebooting: "Rebooting", s_window: "Outside window", s_problems: "With problems",
    b_OK: "OK", b_WARN: "Warning", b_FAIL: "Failed", b_ROLLBACK: "Rolled back", b_SKIP: "Skipped", b_TEST: "Checked", b_RUN: "Running",
    ago_s: "just now", ago_m: "{n} min ago", ago_h: "{n} h ago", ago_d: "{n} d ago", in_x: "in {x}",
    up_to_date: "up to date", reboot_needed: "reboot needed",
    os_windows: "Windows", os_linux: "Linux", main_nav: "Main", language: "Language",
    dashboard: "Dashboard", sub_guests: "{n} systems · {a} automatic",
    sub_history: "The last {n} runs", sub_settings: "Schedule, notifications, program updates and appearance",
    st_avail: "Updates available", per_check: "last check",
    st_updated: "Updated", st_updated_s: "systems updated", st_problems: "Problems", st_problems_s: "rollbacks and errors",
    st_runs: "Runs", days14: "14 days", m_uptodate: "{n} up to date", m_pending: "{n} with updates",
    sys_status: "System status",
    window_l: "Update window", open_w: "open now", closed_w: "closed now",
    recent_runs: "Recent runs", all_runs: "Show all runs", more_actions: "More actions", account: "Account", full_access: "Full access",
    clear_sel: "Clear selection", report_issue: "Report a problem", donate: "Donate", pending_n: "{n} pending",
    duration: "Duration", theme: "Theme", th_auto: "System", th_light: "Light", th_dark: "Dark", appearance: "Appearance",
    theme_sub: "System follows the setting of your device.", lang_sub: "Remembered in this browser.", id_on: "ID {id} · {node}",
    next_x: "Next run {x}", no_schedule: "No schedule", systems: "systems",
    hs_ok: "Up to date", hs_pend: "Updates available", hs_bad: "Problem at last run", hs_none: "Not checked yet",
    sched_hint: "Schedule and time window are set on the node: pve-autoupdate setup", about: "About", ui_version: "Web UI", author: "Author",
  },
  de: {
    report_systems: "Systeme", report_packages: "Installierte Pakete", report_results: "Systemergebnisse", no_attention: "Kein Handlungsbedarf gemeldet.",
    mail_theme: "Farbschema der Statusmail", mail_preview: "Mailvorschau", site_links: "Meine Links", project_by: "Ein Projekt von", sample_attention: "Handlungsbedarf", sample_success: "Erfolgreicher Lauf", sample_dryrun: "Testlauf",
    upd_title: "Neue Version {v} verfügbar", upd_installed: "installiert: {v}", upd_whatsnew: "Neu in dieser Version", upd_now: "Jetzt aktualisieren",
    upd_check: "Jetzt prüfen", upd_section: "Programm-Updates", upd_installed_l: "Installierte Version", upd_latest_l: "Neueste Version",
    upd_checked_l: "Letzte Prüfung", upd_none: "noch nicht geprüft", upd_uptodate: "Aktuell.", upd_checking: "Frage GitHub ...",
    upd_unreach: "GitHub nicht erreichbar - keine Prüfung möglich (privates Repository oder kein Internet).",
    upd_confirm_t: "Update installieren?", upd_confirm_p: "pve-autoupdate {v} wird von GitHub geladen und auf dem Node installiert. Die Weboberfläche startet dabei neu, diese Seite lädt danach von selbst neu - eventuell musst du dich neu anmelden.",
    upd_running: "Das Update läuft - diese Seite lädt gleich von selbst neu ...", upd_failed: "Das Update konnte nicht gestartet werden",
    upd_hint_cli: "Im Terminal: pve-autoupdate update-check / pve-autoupdate self-update. GitHub wird höchstens alle 12 Stunden gefragt, installiert wird nichts ohne dich.",
    settings: "Einstellungen", set_mail: "Benachrichtigung per Mail", set_mail_sub: "Einen Bericht per Mail bekommen, nachdem die Updates gelaufen sind.",
    set_notify: "Wann soll eine Mail kommen", n_never: "Nie", n_errors: "Nur wenn etwas schiefgelaufen ist", n_changes: "Bei Problemen und wenn etwas aktualisiert wurde", n_always: "Nach jedem Lauf",
    set_to: "Empfänger", set_to_ph: "name@example.com (mehrere mit Komma trennen)",
    set_transport: "Versand", tr_system: "Proxmox-Mailsystem (postfix)", tr_smtp: "Eigener SMTP-Server (z. B. Gmail mit App-Passwort)",
    set_from: "Absender (leer = automatisch)", set_title: "Name im Betreff",
    set_host: "SMTP-Server", set_port: "Port", set_sec: "Verschlüsselung", sec_starttls: "STARTTLS (meist Port 587)", sec_ssl: "SSL/TLS (meist Port 465)", sec_none: "keine (Port 25, nur im LAN)",
    set_user: "Benutzername (leer = ohne Anmeldung)", set_pass: "Passwort bzw. App-Passwort", set_pass_kept: "gespeichert - leer lassen, um es zu behalten",
    set_save: "Speichern", set_save_test: "Speichern und Testmail senden", set_saved: "Gespeichert.", sending: "Testmail wird verschickt ...",
    set_test_ok: "Gespeichert. Die Testmail wurde übergeben - schau in dein Postfach.", set_test_fail: "Gespeichert, aber die Testmail ging nicht raus:",
    set_err: "Speichern fehlgeschlagen", need_to: "Bitte eine gültige Mail-Adresse eintragen.", need_host: "Bitte den SMTP-Server eintragen.", need_port: "Bitte einen Port eintragen (1-65535).",
    mail_off_hint: "Mail-Benachrichtigung ist aus - bei fehlgeschlagenen Updates erfährst du nichts.", mail_set_up: "Jetzt einrichten",
    set_ro: "Dein Konto darf Einstellungen ansehen, aber nicht ändern (Sys.Modify nötig).",
    login_title: "Anmelden", login_sub: "mit deinem Proxmox-VE-Konto", user: "Benutzername", password: "Passwort",
    realm: "Realm", sign_in: "Anmelden", code: "Zwei-Faktor-Code", code_hint: "Code aus deiner Authenticator-App (oder ein Recovery-Key)",
    verify: "Bestätigen", bad_login: "Anmeldung fehlgeschlagen - Benutzername, Passwort und Realm prüfen.", bad_code: "Der Code ist nicht gültig.",
    no_permission: "Dieses Konto darf die Nodes nicht sehen (Sys.Audit nötig).", too_many_attempts: "Zu viele Fehlversuche - bitte ein paar Minuten warten.",
    expired: "Das hat zu lange gedauert - bitte neu anmelden.", node_down: "Der Proxmox-Node antwortet nicht",
    overview: "Übersicht", history: "Verlauf", logout: "Abmelden", read_only: "nur lesen",
    ro_banner: "Dein Konto darf alles sehen, aber keine Updates starten (Sys.Modify nötig).",
    schedule: "Zeitplan", next_run: "Nächster Lauf", last_run: "Letzter Lauf", state: "Status",
    window_open: "Zeitfenster offen", window_closed: "außerhalb des Zeitfensters", no_window: "kein Zeitfenster",
    idle: "Bereit", running: "Update läuft", reboot_pending: "Node-Neustart läuft (Nachkontrolle folgt)",
    never: "noch nie", nodes: "Nodes", guests: "System", kind_ct: "Container (LXC)", kind_vm: "Virtuelle Maschine",
    check: "Prüfen", update: "Aktualisieren", update_reboot: "Aktualisieren + Neustart", check_all: "Alles prüfen", update_all: "Alles aktualisieren",
    online: "online", offline: "offline", last_update: "Letztes Update", last_check: "Letzte Prüfung", none_yet: "noch nichts",
    search: "Name oder ID suchen", all: "Alle", cts: "Container", vms: "VMs", auto_only: "Automatisch",
    selected: "ausgewählt", auto: "Automatisch", auto_tip: "wird nach Zeitplan aktualisiert", manual_tip: "nur wenn du es hier startest",
    id: "ID", name: "Name", type: "Typ", node: "Node", status: "Status", actions: "Aktionen", yes: "ja", no: "nein",
    st_running: "läuft", st_stopped: "gestoppt", template: "Vorlage", ui_node: "Mit diesem Node spricht die Weboberfläche",
    no_guests: "Keine Container oder VMs gefunden.", no_match: "Nichts passt zum Filter.",
    run_check: "Prüfung läuft", run_update: "Update läuft", run_done: "Fertig", run_aborted: "Abgebrochen",
    run_rebooting: "Nodes starten neu - die Nachkontrolle folgt nach dem Start", run_window: "Nichts getan - außerhalb des Update-Zeitfensters", close: "Schließen", waiting: "Warte auf das erste Ergebnis ...",
    cancel: "Abbrechen", start: "Starten", dismiss: "Ausblenden",
    m_check_t: "Nach Updates suchen", m_check_p: "Schaut nur nach - es wird nichts installiert oder verändert.",
    m_update_t: "Updates jetzt installieren", m_update_p: "Vor jedem Update wird ein Snapshot angelegt. Schlägt der Health-Check danach fehl, wird der Gast automatisch zurückgesetzt.",
    m_all: "Alles, was auf automatisch steht", allow_reboot: "Neu starten, wenn ein Update es braucht",
    allow_reboot_node: "Node bei Bedarf neu starten (Cluster: nacheinander, Quorum wird geprüft; Gäste darauf sind kurz offline)",
    outside_window: "Es ist außerhalb des Update-Zeitfensters ({w}).", force_window: "Trotzdem ausführen",
    started: "Gestartet", already_running: "Es läuft bereits ein Update.", failed_start: "Konnte nicht starten",
    h_when: "Gestartet", h_kind: "Art", h_target: "Ziele", h_result: "Ergebnis", h_by: "Von",
    k_update: "Update", k_check: "Prüfung", by_ui: "Weboberfläche", by_cli: "Zeitplan / Konsole", all_selected: "alle automatischen",
    no_history: "Noch keine Läufe.", no_history_p: "Läufe erscheinen hier, sobald der Zeitplan gelaufen ist oder du auf der Übersicht eine Prüfung startest.", go_overview: "Zur Übersicht",
    back: "Zurück", results: "Ergebnisse", events: "Protokoll dieses Laufs", refresh: "Aktualisieren", no_results: "Keine Ergebnisse in diesem Lauf.",
    pkgs: "{n} Pak.", post: "Nachkontrolle",
    s_running: "Läuft", s_ok: "OK", s_fail: "Fehler", s_aborted: "Abgebrochen", s_rebooting: "Neustart", s_window: "Außerhalb Zeitfenster", s_problems: "Mit Problemen",
    b_OK: "OK", b_WARN: "Warnung", b_FAIL: "Fehler", b_ROLLBACK: "Zurückgesetzt", b_SKIP: "Übersprungen", b_TEST: "Geprüft", b_RUN: "Läuft",
    ago_s: "gerade eben", ago_m: "vor {n} Min.", ago_h: "vor {n} Std.", ago_d: "vor {n} Tg.", in_x: "in {x}",
    up_to_date: "aktuell", reboot_needed: "Neustart nötig",
    os_windows: "Windows", os_linux: "Linux", main_nav: "Hauptmenü", language: "Sprache",
    dashboard: "Übersicht", sub_guests: "{n} Systeme · {a} automatisch",
    sub_history: "Die letzten {n} Läufe", sub_settings: "Zeitplan, Benachrichtigungen, Programm-Updates und Darstellung",
    st_avail: "Updates verfügbar", per_check: "letzte Prüfung",
    st_updated: "Aktualisiert", st_updated_s: "Systeme aktualisiert", st_problems: "Probleme", st_problems_s: "Rollbacks und Fehler",
    st_runs: "Läufe", days14: "14 Tage", m_uptodate: "{n} aktuell", m_pending: "{n} mit Updates",
    sys_status: "Systemstatus",
    window_l: "Update-Zeitfenster", open_w: "gerade offen", closed_w: "gerade geschlossen",
    recent_runs: "Letzte Läufe", all_runs: "Alle Läufe anzeigen", more_actions: "Weitere Aktionen", account: "Konto", full_access: "Vollzugriff",
    clear_sel: "Auswahl aufheben", report_issue: "Problem melden", donate: "Spenden", pending_n: "{n} offen",
    duration: "Dauer", theme: "Design", th_auto: "System", th_light: "Hell", th_dark: "Dunkel", appearance: "Darstellung",
    theme_sub: "System folgt der Einstellung deines Geräts.", lang_sub: "Wird in diesem Browser gespeichert.", id_on: "ID {id} · {node}",
    next_x: "Nächster Lauf {x}", no_schedule: "Kein Zeitplan", systems: "Systeme",
    hs_ok: "Aktuell", hs_pend: "Updates verfügbar", hs_bad: "Problem beim letzten Lauf", hs_none: "Noch nicht geprüft",
    sched_hint: "Zeitplan und Zeitfenster werden auf dem Node eingestellt: pve-autoupdate setup", about: "Info", ui_version: "Weboberfläche", author: "Autor",
  },
};

// ------------------------------------------------------------------ state
const TABS = ["overview", "guests", "history", "settings"];
const S = {
  lang: loadPref("lang") || ((navigator.language || "en").slice(0, 2) === "de" ? "de" : "en"),
  theme: loadPref("theme") || "auto",
  session: null, inv: null, invErr: "", history: null, tab: "overview",
  filter: loadPref("filter") || "all", q: "", picked: new Set(),
  run: null,            // {id, from, events, done, mode}
  detail: null,         // {id, events, loading}
  menu: null,           // open dropdown: "acct" or "node:<name>"
  loginErr: "", tfa: null, busy: false,
};
let pollRun = null, pollInv = null;

function loadPref(k) { try { return localStorage.getItem("pveau." + k); } catch (e) { return null; } }
function savePref(k, v) { try { localStorage.setItem("pveau." + k, v); } catch (e) { /* private mode */ } }
function t(k, vars) {
  let s = (TXT[S.lang] && TXT[S.lang][k]) || TXT.en[k] || k;
  if (vars) for (const [a, b] of Object.entries(vars)) s = s.replace("{" + a + "}", b);
  return s;
}
function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
const $ = sel => document.querySelector(sel);
const locale = () => (S.lang === "de" ? "de-DE" : "en-GB");
function applyTheme() { document.documentElement.dataset.theme = S.theme; }
applyTheme();

// ------------------------------------------------------------------ icons (24px grid, 1.75 stroke, see .ic)
const ICONS = {
  check: "M5 12.5l4.5 4.5L19 7.5",
  back: "M19 12H5M11 18l-6-6 6-6",
  refresh: "M20 12a8 8 0 1 1-2.34-5.66M20 4v5h-5",
  logout: "M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l-5-5 5-5M5 12h11",
  heart: "M12 19.5s-7-4.2-7-9.2A3.8 3.8 0 0 1 12 8a3.8 3.8 0 0 1 7 2.3c0 5-7 9.2-7 9.2z",
  search: "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-3.5-3.5",
  x: "M6 6l12 12M18 6L6 18",
  alert: "M12 3.5L21.5 20h-19zM12 10v4.5M12 17.5v.01",
  info: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v5.5M12 7.5v.01",
  up: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 16.5v-9M8.5 11L12 7.5l3.5 3.5",
  mail: "M3.5 6h17v12h-17zM4 6.5l8 6.5 8-6.5",
  lock: "M7.5 11V8a4.5 4.5 0 0 1 9 0v3M5.5 11h13v9.5h-13z",
  grid: "M4 4h6.5v6.5H4zM13.5 4H20v6.5h-6.5zM4 13.5h6.5V20H4zM13.5 13.5H20V20h-6.5z",
  box: "M12 3l8 4.5v9L12 21l-8-4.5v-9zM4 7.5l8 4.5 8-4.5M12 12v9",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7.5V12l3 2",
  sliders: "M4 7h10M18 7h2M4 17h2M10 17h10M16 5v4M8 15v4",
  sun: "M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 3v1.5M12 19.5V21M3 12h1.5M19.5 12H21M5.6 5.6l1.1 1.1M17.3 17.3l1.1 1.1M5.6 18.4l1.1-1.1M17.3 6.7l1.1-1.1",
  moon: "M19.5 14.5A7.5 7.5 0 0 1 9.5 4.5a7.5 7.5 0 1 0 10 10z",
  monitor: "M3.5 5h17v11h-17zM9 20h6M12 16v4",
  user: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20a7.5 7.5 0 0 1 15 0",
  down: "M6 9l6 6 6-6",
  right: "M9 6l6 6-6 6",
  dots: "M12 5.5v.01M12 12v.01M12 18.5v.01",
  dl: "M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19.5h14",
  power: "M12 3.5V11M7 6.5a7 7 0 1 0 10 0",
  server: "M4 4.5h16v6H4zM4 13.5h16v6H4zM7.5 7.5h.01M7.5 16.5h.01",
};
function icon(n) { return `<svg class="ic${n === "dots" ? " dots" : ""}" viewBox="0 0 24 24" aria-hidden="true"><path d="${ICONS[n]}"/></svg>`; }

// ------------------------------------------------------------------ API
async function api(path, opts = {}) {
  const o = { method: opts.method || "GET", credentials: "same-origin", headers: {} };
  if (opts.body !== undefined) {
    o.method = "POST";
    o.headers["Content-Type"] = "application/json";
    o.body = JSON.stringify(opts.body);
  }
  if (o.method === "POST" && S.session) o.headers["X-PVEAU-CSRF"] = S.session.csrf;
  const r = await fetch(path, o);
  if (r.status === 401 && path !== "/api/login" && path !== "/api/session") {
    S.session = null; stopPolling(); render(); throw new Error("login");
  }
  const ct = r.headers.get("Content-Type") || "";
  const data = ct.includes("json") ? await r.json() : await r.text();
  return { ok: r.ok, status: r.status, data };
}

// ------------------------------------------------------------------ time helpers
function ago(ts) {
  if (!ts) return "";
  const d = Math.max(0, Date.now() / 1000 - ts);
  if (d < 60) return t("ago_s");
  if (d < 3600) return t("ago_m", { n: Math.round(d / 60) });
  if (d < 86400) return t("ago_h", { n: Math.round(d / 3600) });
  return t("ago_d", { n: Math.round(d / 86400) });
}
function fmt(ts) {
  if (!ts) return "";
  return new Date(ts * 1000).toLocaleString(locale(), { dateStyle: "medium", timeStyle: "short" });
}
function clock(ts) { return new Date(ts * 1000).toLocaleTimeString(locale()); }
function dur(s) {
  s = Math.max(0, Math.round(s));
  if (s < 60) return s + " s";
  if (s < 3600) return Math.round(s / 60) + " min";
  return Math.floor(s / 3600) + " h " + Math.round((s % 3600) / 60) + " min";
}
function runTs(id) {   // 20261021-030000 -> unix ts (node local time ~ browser local time)
  const m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})$/.exec(id || "");
  return m ? new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() / 1000 : 0;
}
function nextRunTxt(s) {
  if (!s || /not scheduled|nicht geplant/.test(s)) return { v: s || "-", s: "", none: true };
  const d = new Date(s.replace(/^\w{3} /, "").replace(/ [A-Z]{2,5}$/, ""));
  if (isNaN(d)) return { v: s, s: "" };
  const diff = d.getTime() / 1000 - Date.now() / 1000;
  let rel = "";
  if (diff > 0) {
    rel = diff < 3600 ? Math.round(diff / 60) + " min" : diff < 86400 ? Math.round(diff / 3600) + " h" : Math.round(diff / 86400) + (S.lang === "de" ? " Tg." : " d");
    rel = t("in_x", { x: rel });
  }
  return { v: fmt(d.getTime() / 1000), s: rel };
}

// ------------------------------------------------------------------ small renderers
function badge(st, label) { return `<span class="badge b-${esc(st)}">${esc(label || t("b_" + st))}</span>`; }
function runStatusBadge(st, problems) {   // a run that ended "ok" can still have rollbacks or warnings
  if (st === "ok" && +problems > 0) return badge("WARN", t("s_problems"));
  const map = { ok: ["OK", "s_ok"], fail: ["FAIL", "s_fail"], running: ["RUN", "s_running"], aborted: ["SKIP", "s_aborted"], rebooting: ["TEST", "s_rebooting"], window: ["SKIP", "s_window"] };
  const m = map[st] || ["SKIP", st];
  return badge(m[0], t(m[1]));
}
// mail subjects carry prefixes and emoji ("[TEST] [homelab] Updates: ✅ 3 packages updated") - the UI shows the plain text
function cleanSubj(s) {
  const c = String(s || "").replace(/^(\s*\[[^\]]*\])+\s*/, "").replace(/^Updates:\s*/, "")
    .replace(/\p{Extended_Pictographic}️?/gu, "").replace(/\s{2,}/g, " ").trim();
  return c.charAt(0).toUpperCase() + c.slice(1);
}
function kindIcon(g) {   // like Proxmox: cube = container (LXC), screen = virtual machine
  const k = g.type === "qemu" ? "vm" : "ct", label = t("kind_" + k);
  return `<span class="gk ${k}" title="${esc(label)}">${icon(k === "vm" ? "monitor" : "box")}<span class="sr">${esc(label)}</span></span>`;
}
function osTag(g) {   // operating system only - the kind is shown by kindIcon()
  const os = (g.os || "").toLowerCase();
  if (os.startsWith("w")) return `<span class="tag win">${t("os_windows")}</span>`;
  if (!os) return "";
  if (os === "l26" || os === "l24") return `<span class="tag">${t("os_linux")}</span>`;
  return `<span class="tag">${esc(os)}</span>`;
}
function shortIp(ip) {   // long IPv6 addresses: first two and the last group, the full address goes into the tooltip
  const s = String(ip || ""), p = s.split(":");
  return p.length > 4 ? `${p[0]}:${p[1]}:…:${p[p.length - 1]}` : s;
}
function kindTxt(mode) { return mode === "dryrun" ? `<span class="kind">${icon("search")}${t("k_check")}</span>` : `<span class="kind">${icon("dl")}${t("k_update")}</span>`; }
function resultCell(r, slot) {
  if (!r || !r[slot]) return `<span class="faint">${t("none_yet")}</span>`;
  const x = r[slot];
  let sum = x.summary || "";
  if (x.reboot) sum += " · " + t("reboot_needed");
  return `<div class="rc" title="${esc(fmt(x.ts) + " - " + sum)}">${badge(x.status)}<span>${esc(sum)}</span><small>${esc(ago(x.ts))}</small></div>`;
}
function skeleton(lines) { return `<div class="card sk-block" aria-busy="true">${'<span class="sk"></span>'.repeat(lines || 3)}</div>`; }
function phead(title, sub, actions) {
  return `<div class="phead"><div><h1>${title}</h1>${sub ? `<p>${sub}</p>` : ""}</div>${actions ? `<div class="actions">${actions}</div>` : ""}</div>`;
}
function chead(title, count, actions) {
  return `<div class="chead"><h2>${title}</h2>${count != null ? `<span class="count">${count}</span>` : ""}${actions ? `<div class="actions">${actions}</div>` : ""}</div>`;
}
function note(kind, ic, html, act) {
  return `<div class="note ${kind}">${icon(ic)}<div class="txt">${html}</div>${act ? `<div class="act">${act}</div>` : ""}</div>`;
}
function lastOf(kind, id) { return (S.inv && S.inv.last && S.inv.last[kind + ":" + id]) || null; }
const canWrite = () => S.session && S.session.write;
const isRunning = () => (S.inv && S.inv.running) || (S.run && !S.run.done);
const guestKind = g => (g.type === "qemu" ? "VM" : "LXC");
const realGuests = () => ((S.inv && S.inv.guests) || []).filter(g => !g.template);

// ------------------------------------------------------------------ toasts (replace alert())
function toast(text, kind) {
  const box = $("#toasts");
  if (!box) return;
  const el = document.createElement("div");
  el.className = "toast " + (kind || "");
  el.setAttribute("role", kind === "err" ? "alert" : "status");
  el.innerHTML = `${icon(kind === "err" ? "alert" : kind === "ok" ? "check" : "info")}<div class="txt">${esc(text)}</div>
    <button type="button" class="btn ghost sm icon" aria-label="${esc(t("dismiss"))}">${icon("x")}</button>`;
  const kill = () => { if (el.classList.contains("out")) return; el.classList.add("out"); setTimeout(() => el.remove(), 180); };
  el.querySelector("button").addEventListener("click", kill);
  box.appendChild(el);
  setTimeout(kill, kind === "err" ? 9000 : 4500);
}

// ------------------------------------------------------------------ theme + language controls
function themeSwitch() {
  const b = (v, ic) => `<button type="button" data-act="theme" data-v="${v}" class="${S.theme === v ? "on" : ""}" aria-pressed="${S.theme === v}"
    title="${t("th_" + v)}" aria-label="${t("th_" + v)}">${icon(ic)}</button>`;
  return `<div class="seg icons" role="group" aria-label="${t("theme")}">${b("auto", "monitor")}${b("light", "sun")}${b("dark", "moon")}</div>`;
}
function langSelect() {
  const o = (v, l) => `<option value="${v}" ${S.lang === v ? "selected" : ""}>${l}</option>`;
  return `<select class="langsel" data-langsel aria-label="${t("language")}">${o("en", "English")}${o("de", "Deutsch")}</select>`;
}

// ------------------------------------------------------------------ login
function renderLogin() {
  const realms = S.realms || [{ realm: "pam", comment: "Linux PAM" }, { realm: "pve", comment: "Proxmox VE" }];
  const err = S.loginErr ? note("err", "alert", esc(S.loginErr)) : "";
  const btn = label => `<button class="btn primary" ${S.busy ? "disabled" : ""}>${S.busy ? '<span class="spin"></span>' : ""}${label}</button>`;
  let form;
  if (S.tfa) {
    form = `<form id="f-tfa">${err}
      <label class="field"><span>${t("code")}</span><input id="code" autocomplete="one-time-code" inputmode="numeric" required autofocus>
        <small class="hint">${t("code_hint")}</small></label>
      ${btn(t("verify"))}</form>`;
  } else {
    form = `<form id="f-login">${err}
      <label class="field"><span>${t("user")}</span><input id="user" autocomplete="username" value="root" required></label>
      <label class="field"><span>${t("password")}</span><input id="pw" type="password" autocomplete="current-password" required autofocus></label>
      <label class="field"><span>${t("realm")}</span><select id="realm">${realms.map(r =>
        `<option value="${esc(r.realm)}">${esc(r.comment || r.realm)} (${esc(r.realm)})</option>`).join("")}</select></label>
      ${btn(t("sign_in"))}</form>`;
  }
  return `<main class="login"><div class="wrap">
    <img class="biglogo" src="logo.svg" alt="PVE Autoupdate" width="440" height="399">
    <div class="card">
      <h1>${t("login_title")}</h1>
      <p class="sub">${t("login_sub")}${S.node ? ` · <span class="mono">${esc(S.node)}</span>` : ""}</p>
      ${form}
    </div>
    <div class="foot"><span>by ${esc(AUTHOR)} · <a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a></span>
      <div class="ctl">${themeSwitch()}${langSelect()}</div></div>
  </div></main>`;
}

async function doLogin(body) {
  S.busy = true; S.loginErr = ""; render();
  try {
    const r = await api("/api/login", { body });
    if (r.ok && r.data.tfa) { S.tfa = r.data.pending; }
    else if (r.ok) { S.tfa = null; await boot(); return; }
    else {
      const e = r.data && r.data.error;
      if (e === "expired") S.tfa = null;
      S.loginErr = r.status === 502 ? t("node_down") + ": " + (r.data.detail || "") : t(e || "bad_login");
    }
  } catch (e) { S.loginErr = t("node_down"); }
  S.busy = false; render();
}

// ------------------------------------------------------------------ app shell: sidebar (phone: top bar + tab bar)
function wherePlace() {
  const inv = S.inv;
  return inv ? (inv.cluster ? "Cluster " + inv.cluster : "Node " + inv.self) : (S.session.node || "");
}
function sideStatus() {
  const inv = S.inv;
  if (!inv) return "";
  let h;
  if (isRunning()) h = `<div class="sstat"><span class="spin"></span><div>${t("running")}</div></div>`;
  else if (inv.reboot_pending) h = `<div class="sstat"><span class="dot wait"></span><div>${t("s_rebooting")}</div></div>`;
  else {
    const nr = nextRunTxt(inv.next_run);
    h = `<div class="sstat"><span class="dot on"></span><div>${t("idle")}<small>${nr.none ? t("no_schedule") : esc(t("next_x", { x: nr.s || nr.v }))}</small></div></div>`;
  }
  if (inv.update_available) h = `<a class="supd" href="#/settings">${icon("up")}${esc(t("upd_title", { v: inv.latest_version }))}</a>` + h;
  return h;
}
function accountMenu(key) {
  const open = S.menu === key, u = S.session.user || "";
  return `<div class="mwrap"><button class="acct" data-act="menu" data-v="${key}" aria-haspopup="menu" aria-expanded="${open}" aria-label="${t("account")}">
      <span class="avatar" aria-hidden="true">${esc(u.charAt(0))}</span>
      <span class="who"><b>${esc(u)}</b><small>${canWrite() ? t("full_access") : t("read_only")}</small></span>${icon("down")}</button>
    ${open ? `<div class="menu" role="menu"><div class="mhead"><b>${esc(u)}</b><span>${esc(wherePlace())}</span>
        <span>${canWrite() ? `${icon("check")}${t("full_access")}` : `${icon("lock")}${t("read_only")}`}</span></div>
      <button role="menuitem" data-act="logout">${icon("logout")}${t("logout")}</button></div>` : ""}</div>`;
}
function renderApp() {
  const nav = (k, ic, label) => `<a href="#/${k}" class="${S.tab === k ? "on" : ""}" ${S.tab === k ? 'aria-current="page"' : ""}>${icon(ic)}<span>${label}</span></a>`;
  let body = "";
  if (S.tab === "overview") body = renderOverview();
  else if (S.tab === "guests") body = renderGuestsPage();
  else if (S.tab === "history") body = S.detail ? renderDetail() : renderHistory();
  else body = renderSettings();
  const brand = `<a class="brand" href="#/overview"><img src="emblem.svg" alt="" width="240" height="177"><span><b>PVE Autoupdate</b><small>${esc(wherePlace())}</small></span></a>`;
  return `<aside class="sidebar">${brand}
      <nav class="nav" aria-label="${t("main_nav")}">${nav("overview", "grid", t("dashboard"))}${nav("guests", "server", t("guests"))}${nav("history", "clock", t("history"))}${nav("settings", "sliders", t("settings"))}</nav>
      <div class="side-foot">${sideStatus()}${accountMenu("acct")}</div>
    </aside>
    <header class="mtop">${brand}${accountMenu("acct-m")}</header>
    <main><div class="page">${body}</div><footer class="project-footer"><div><b>PVE Autoupdate</b><small>${t("project_by")} ${AUTHOR}</small></div>
      <nav aria-label="${t("site_links")}"><a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a>
      <a href="https://links.kaimazon.de" target="_blank" rel="noopener">${t("site_links")}</a>
      ${hasDonate() ? `<a href="${DONATE_URL}" target="_blank" rel="noopener">${t("donate")}</a>` : ""}</nav></footer></main>`;
}
function topNotes() {   // problems that matter on every operational page
  let h = S.invErr ? note("err", "alert", `<b>${t("node_down")}</b> · ${esc(S.invErr)}`) : "";
  if (!canWrite() && S.tab === "guests") h += note("", "lock", t("ro_banner"));
  return h;
}
function bulkActions() {
  if (!canWrite() || !S.inv) return "";
  const dis = isRunning() ? "disabled" : "";
  return `<button class="btn" data-act="go" data-mode="check" ${dis}>${icon("search")}${t("check_all")}</button>
    <button class="btn primary" data-act="go" data-mode="update" ${dis}>${icon("dl")}${t("update_all")}</button>`;
}

// ------------------------------------------------------------------ dashboard numbers
const DAYS = 14;
function dayStart() { const n = new Date(); return new Date(n.getFullYear(), n.getMonth(), n.getDate() - (DAYS - 1)).getTime() / 1000; }
function stats() {
  const start = dayStart(), z = () => new Array(DAYS).fill(0);
  const s = { changes: z(), problems: z(), runs: z(), upd: 0, chk: 0, start };
  for (const r of S.history || []) {
    const ts = r.start || runTs(r.id);
    if (!ts || ts < start) continue;
    const i = Math.min(DAYS - 1, Math.floor((ts - start) / 86400));
    s.runs[i]++;
    s.problems[i] += +r.problems || 0;
    if (r.mode === "dryrun") s.chk++;
    else { s.upd++; s.changes[i] += +r.changes || 0; }
  }
  // pending: the last check found packages and no update ran after it
  const sys = realGuests().map(g => lastOf(guestKind(g), g.id)).concat((S.inv.nodes || []).map(n => lastOf("NODE", n.name)));
  s.total = sys.length; s.pendSys = 0; s.pend = 0;
  for (const l of sys) {
    if (l && l.check && +l.check.pkgs > 0 && (!l.update || l.update.ts < l.check.ts)) { s.pendSys++; s.pend += +l.check.pkgs; }
  }
  return s;
}
function pendingOf(l) { return l && l.check && +l.check.pkgs > 0 && (!l.update || l.update.ts < l.check.ts) ? +l.check.pkgs : 0; }
const sum = a => a.reduce((x, y) => x + y, 0);
const num = n => Number(n).toLocaleString(locale());

// one bar per day for the last 14 days; empty days keep a thin stub so the rhythm stays readable
function spark(vals, start, label) {
  const W = 280, H = 44, n = vals.length, max = Math.max(1, ...vals), gap = 5, bw = (W - gap * (n - 1)) / n;
  const f = v => v.toFixed(1);
  const bars = vals.map((v, i) => {
    const h = v ? Math.max(5, (v / max) * H) : 2, x = i * (bw + gap);
    const day = new Date((start + i * 86400 + 43200) * 1000).toLocaleDateString(locale(), { day: "numeric", month: "short" });
    return `<g><title>${esc(day)}: ${num(v)} ${esc(label)}</title><rect class="hit" x="${f(x)}" y="0" width="${f(bw)}" height="${H}"/>
      <rect class="bar${v ? "" : " zero"}${i === n - 1 ? " today" : ""}" x="${f(x)}" y="${f(H - h)}" width="${f(bw)}" height="${f(h)}" rx="1.5"/></g>`;
  }).join("");
  return `<svg class="spark" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" role="img" aria-label="${esc(label)}, ${t("days14")}">${bars}</svg>`;
}
function statCard(cls, label, per, value, viz) {
  return `<section class="card stat ${cls}"><div class="top-row"><span class="lbl">${label}</span><span class="per">${per}</span></div>
    <div class="num ${+value ? "" : "zero"}">${num(value)}</div><div class="viz">${viz}</div></section>`;
}

// ------------------------------------------------------------------ overview (dashboard)
function latestReport(run) {
  if (!run || !Array.isArray(run.systems)) return "";
  const rows = run.systems;
  const problems = rows.filter(r => ["FAIL","WARN","ROLLBACK"].includes(r.status) || r.reboot);
  const cells = rows.map(r => `<tr><td><b>${esc(r.name || r.id)}</b><div class="l2">${esc(r.kind)} · ${esc(r.node)}</div></td>
    <td>${badge(r.status)}</td><td>${esc(r.summary)}${r.reboot ? " · " + t("reboot_needed") : ""}</td></tr>`).join("");
  const counts = [[t("report_systems"),rows.length],[t("report_packages"),run.packages || 0],
    [t("b_ROLLBACK"),rows.filter(r => r.status === "ROLLBACK").length],[t("reboot_needed"),rows.filter(r => r.reboot).length]];
  const metrics = counts.map(([label,n])=>`<div class="card stat"><span class="lbl">${label}</span><div class="num">${num(n)}</div></div>`).join("");
  const days = stats(), trend = Array(DAYS).fill(0);
  for (const h of S.history || []) {
    const i = Math.floor(((h.start || 0) - days.start) / 86400);
    if (i >= 0 && i < DAYS && h.mode === "live") trend[i] += h.packages || 0;
  }
  const attention = problems.map(r=>`<li><a href="#/history/${encodeURIComponent(run.id)}"><b>${esc(r.name || r.id)}</b> · ${r.reboot ? t("reboot_needed") : t("b_"+r.status)}</a></li>`).join("");
  return `<div class="grid g4">${metrics}</div><div class="grid grid2">
    <section class="card">${chead(t("report_packages"), null,t("days14"))}<div class="cbody">${spark(trend,days.start,t("report_packages"))}</div></section>
    <section class="card">${chead(t("sample_attention"))}<div class="cbody">${attention ? "<ul>"+attention+"</ul>" : t("no_attention")}</div></section></div>
    <section class="card">${chead(t("report_results"),null,`<a href="#/history/${encodeURIComponent(run.id)}">${esc(fmt(run.start))}</a>`)}
    <div class="tblwrap"><table class="tbl"><thead><tr><th>${t("name")}</th><th>${t("status")}</th><th>${t("report_results")}</th></tr></thead><tbody>${cells}</tbody></table></div></section>`;
}


function renderOverview() {
  const inv = S.inv;
  if (!inv) return phead(t("dashboard")) + `<div class="grid g4">${skeleton(3).repeat(4)}</div><div class="grid g3">${skeleton(5).repeat(3)}</div>`;
  const st = stats(), nr = nextRunTxt(inv.next_run);
  const sub = esc(wherePlace() + " · " + (nr.none ? t("no_schedule") : t("next_x", { x: nr.s || nr.v })));
  const report = latestReport((S.history || []).find(r => Array.isArray(r.systems)));
  if (report) return phead(t("dashboard"), sub, `<a class="btn" href="#/settings">${t("mail_preview")}</a>` + bulkActions())
    + topNotes() + renderRun() + report + `<div class="grid g3">${healthCard()}${nodesCard()}${recentCard()}</div>`;
  const upToDate = st.total - st.pendSys, pct = st.total ? (upToDate / st.total) * 100 : 100;
  const meter = `<div class="meter"><svg viewBox="0 0 100 8" preserveAspectRatio="none" aria-hidden="true"><rect class="bg" width="100" height="8"/><rect class="fg" width="${pct.toFixed(1)}" height="8"/></svg>
    <div class="legend"><span>${esc(t("m_uptodate", { n: upToDate }))}</span><span>${esc(t("m_pending", { n: st.pendSys }))}</span></div></div>`;
  const cards = statCard("c-blue", t("st_avail"), t("per_check"), st.pend, meter)
    + statCard("c-green", t("st_updated"), t("days14"), sum(st.changes), spark(st.changes, st.start, t("st_updated_s")))
    + statCard("c-red", t("st_problems"), t("days14"), sum(st.problems), spark(st.problems, st.start, t("st_problems_s")))
    + statCard("c-amber", t("st_runs"), t("days14"), sum(st.runs), spark(st.runs, st.start, t("st_runs")));
  return `${phead(t("dashboard"), sub, `<a class="btn" href="#/settings">${t("mail_preview")}</a>` + bulkActions())}${topNotes()}${renderRun()}
    <div class="grid g4">${cards}</div>
    <div class="grid g3">${healthCard()}${nodesCard()}${recentCard()}</div>`;
}

// every system (guest or node) counts once, by its newest result
function sysState(l) {
  const x = l && [l.update, l.check].filter(Boolean).sort((a, b) => b.ts - a.ts)[0];
  if (!x) return "none";
  if (["FAIL", "ROLLBACK", "WARN"].includes(x.status)) return "bad";
  return pendingOf(l) ? "pend" : "ok";
}
function healthCard() {
  const n = { ok: 0, pend: 0, bad: 0, none: 0 };
  for (const g of realGuests()) n[sysState(lastOf(guestKind(g), g.id))]++;
  for (const x of S.inv.nodes || []) n[sysState(lastOf("NODE", x.name))]++;
  const keys = ["ok", "pend", "bad", "none"], total = sum(keys.map(k => n[k]));
  const R = 52, C = 2 * Math.PI * R, used = keys.filter(k => n[k]), gap = used.length > 1 ? 3 : 0;
  let off = 0;
  const arcs = used.map(k => {
    const len = (n[k] / total) * C;
    const a = `<circle class="arc k-${k}" cx="60" cy="60" r="${R}" stroke-dasharray="${Math.max(0, len - gap).toFixed(2)} ${C.toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}"/>`;
    off += len;
    return a;
  }).join("");
  const legend = keys.map(k => `<li class="k-${k}"><i></i><span>${t("hs_" + k)}</span><b>${num(n[k])}</b></li>`).join("");
  return `<section class="card">${chead(t("sys_status"))}<div class="health">
      <div class="donut"><svg viewBox="0 0 120 120" role="img" aria-label="${esc(t("sys_status"))}"><circle class="trk" cx="60" cy="60" r="${R}"/><g transform="rotate(-90 60 60)">${arcs}</g></svg>
        <div class="mid"><b>${num(total)}</b><span>${t("systems")}</span></div></div>
      <ul class="legend2">${legend}</ul></div></section>`;
}

function nodesCard() {
  const inv = S.inv, w = canWrite(), dis = isRunning() ? "disabled" : "";
  const rows = inv.nodes.map(n => {
    const l = lastOf("NODE", n.name), u = l && l.update, pend = pendingOf(l), key = "node:" + n.name, open = S.menu === key;
    const side = pend ? `<span class="pend">${esc(t("pending_n", { n: pend }))}</span>` : u ? badge(u.status) : "";
    const menu = w ? `<div class="mwrap"><button class="btn ghost sm icon" data-act="menu" data-v="${esc(key)}" aria-haspopup="menu" aria-expanded="${open}"
        aria-label="${esc(t("more_actions") + ": " + n.name)}" title="${t("more_actions")}">${icon("dots")}</button>
      ${open ? `<div class="menu" role="menu">
        <button role="menuitem" data-act="go" data-mode="check" data-t="${esc(key)}" ${dis}>${icon("search")}${t("check")}</button>
        <button role="menuitem" data-act="go" data-mode="update" data-t="${esc(key)}" ${dis}>${icon("dl")}${t("update")}</button>
        <button role="menuitem" class="danger" data-act="go" data-mode="update" data-reboot="yes" data-t="${esc(key)}" ${dis}>${icon("power")}${t("update_reboot")}</button></div>` : ""}</div>` : "";
    return `<li><span class="dot ${n.online ? "on" : "off"}" title="${n.online ? t("online") : t("offline")}"></span>
      <div class="main"><div class="l1"><b>${esc(n.name)}</b>${n.name === inv.self ? `<span class="tag ui" title="${t("ui_node")}">UI</span>` : ""}<span class="ip" title="${esc(n.ip)}">${esc(shortIp(n.ip))}</span></div>
        <div class="l2" title="${esc(u ? u.summary : "")}">${u ? `${t("last_update")} ${esc(ago(u.ts))} · ${esc(u.summary)}` : t("none_yet")}</div></div>
      <div class="side">${side}${menu}</div></li>`;
  }).join("");
  return `<section class="card">${chead(t("nodes"), inv.nodes.length)}<ul class="list">${rows}</ul></section>`;
}

function recentCard() {
  const h = S.history;
  let body;
  if (!h) body = `<div class="sk-block">${'<span class="sk"></span>'.repeat(4)}</div>`;
  else if (!h.length) body = `<div class="empty"><div class="ring idle">${icon("clock")}</div><b>${t("no_history")}</b><p>${t("no_history_p")}</p></div>`;
  else body = `<ul class="list">${h.slice(0, 5).map(r => `<li class="link" data-act="detail" data-v="${esc(r.id)}" tabindex="0">
      <div class="main"><div class="l1">${kindTxt(r.mode)}${runStatusBadge(r.status, r.problems)}</div>
        <div class="l2">${esc(r.subject ? cleanSubj(r.subject) : targetTxt(r.only))}</div></div>
      <div class="side"><span class="when">${esc(ago(r.start || runTs(r.id)))}</span></div></li>`).join("")}</ul>`;
  return `<section class="card">${chead(t("recent_runs"), null, h && h.length ? `<a class="more" href="#/history">${t("all_runs")}${icon("right")}</a>` : "")}${body}</section>`;
}

// ------------------------------------------------------------------ containers & VMs
function visibleGuests() {
  const q = S.q.trim().toLowerCase();
  return realGuests().filter(g => {
    if (S.filter === "lxc" && g.type !== "lxc") return false;
    if (S.filter === "qemu" && g.type !== "qemu") return false;
    if (S.filter === "auto" && !g.selected) return false;
    return !q || String(g.id).includes(q) || (g.name || "").toLowerCase().includes(q);
  });
}
function renderGuestsPage() {
  if (!S.inv) return phead(t("guests")) + skeleton(8);
  const all = realGuests();
  const sub = esc(t("sub_guests", { n: all.length, a: all.filter(g => g.selected).length }));
  return `${phead(t("guests"), sub, bulkActions())}${topNotes()}${renderRun()}${renderGuests()}`;
}
function renderGuests() {
  const all = realGuests();
  const list = visibleGuests();
  const w = canWrite(), dis = isRunning() ? "disabled" : "";
  const seg = (k, l) => `<button type="button" data-act="filter" data-v="${k}" class="${S.filter === k ? "on" : ""}" aria-pressed="${S.filter === k}">${l}</button>`;
  const picked = [...S.picked].filter(id => all.some(g => g.id === id));
  const allPicked = list.length > 0 && list.every(g => S.picked.has(g.id));
  const rows = list.map(g => {
    const l = lastOf(guestKind(g), g.id);
    return `<tr class="${S.picked.has(g.id) ? "picked" : ""}">
      ${w ? `<td class="chk"><input type="checkbox" data-act="pick" data-v="${g.id}" ${S.picked.has(g.id) ? "checked" : ""} aria-label="${esc(g.name)}"></td>` : ""}
      <td class="nm"><div class="l1">${kindIcon(g)}<b title="${esc(g.name)}">${esc(g.name)}</b></div><div class="l2">${osTag(g)}<span class="idm">${esc(t("id_on", { id: g.id, node: g.node }))}</span></div></td>
      <td class="hide-s nw"><span class="st"><span class="dot ${g.status === "running" ? "on" : ""}"></span>${esc(g.status === "running" ? t("st_running") : t("st_stopped"))}</span></td>
      <td class="hide-s" title="${esc(g.selected ? t("auto_tip") : t("manual_tip"))}">${g.selected ? `<span class="yes">${icon("check")}<span class="sr">${t("yes")}</span></span>` : `<span class="no"><span aria-hidden="true">–</span><span class="sr">${t("no")}</span></span>`}</td>
      <td class="res hide-m">${resultCell(l, "check")}</td>
      <td class="res">${resultCell(l, "update")}</td>
      ${w ? `<td class="act"><button class="btn sm" data-act="go" data-mode="check" data-t="${g.id}" ${dis}>${t("check")}</button><button class="btn sm" data-act="go" data-mode="update" data-t="${g.id}" ${dis}>${t("update")}</button></td>` : ""}
    </tr>`;
  }).join("");
  const cols = 5 + (w ? 2 : 0);
  return `<section class="card">
    <div class="toolbar">
      <label class="search">${icon("search")}<span class="sr">${esc(t("search"))}</span><input type="search" id="q" placeholder="${esc(t("search"))}" value="${esc(S.q)}"></label>
      <div class="seg" role="group">${seg("all", t("all"))}${seg("lxc", t("cts"))}${seg("qemu", t("vms"))}${seg("auto", t("auto_only"))}</div>
      ${w && picked.length ? `<div class="selbar"><span>${picked.length} ${t("selected")}</span>
        <button class="btn sm" data-act="go" data-mode="check" data-t="picked" ${dis}>${t("check")}</button>
        <button class="btn sm primary" data-act="go" data-mode="update" data-t="picked" ${dis}>${t("update")}</button>
        <button class="btn sm ghost" data-act="clearsel">${t("clear_sel")}</button></div>` : ""}</div>
    <div class="tblwrap"><table class="tbl"><thead><tr>
      ${w ? `<th class="chk"><input type="checkbox" data-act="pickall" ${allPicked ? "checked" : ""} aria-label="${t("all")}"></th>` : ""}
      <th>${t("name")}</th><th class="hide-s">${t("status")}</th><th class="hide-s">${t("auto")}</th>
      <th class="hide-m">${t("last_check")}</th><th>${t("last_update")}</th>${w ? `<th><span class="sr">${t("actions")}</span></th>` : ""}
    </tr></thead><tbody>${rows || `<tr><td colspan="${cols}" class="empty"><p>${all.length ? t("no_match") : t("no_guests")}</p></td></tr>`}</tbody></table></div>
  </section>`;
}

// ------------------------------------------------------------------ live run panel
function resultRows(events) {
  return events.filter(e => e.ev === "result").map(e => {
    const who = e.kind === "NODE" ? "Node " + e.id : `${e.kind} ${e.id}${e.name ? " (" + e.name + ")" : ""}`;
    return `<div class="r">${badge(e.status)}<span class="who">${esc(who)}</span><span class="sum" title="${esc(e.summary)}">${esc(e.summary)}${e.reboot === "yes" ? " · " + t("reboot_needed") : ""}</span></div>`;
  }).join("");
}
function logLines(events, max) {
  const l = events.filter(e => e.ev === "log").slice(-max);
  return l.map(e => `<div><span class="t">${esc(clock(e.ts))}</span>${esc(e.msg)}</div>`).join("");
}
function renderRun() {
  const r = S.run;
  if (!r) return "";
  const end = r.events.find(e => e.ev === "end");
  const rep = r.events.find(e => e.ev === "report");
  let title, cls = "";
  if (!r.done) title = `<span class="spin"></span><h2>${r.mode === "dryrun" ? t("run_check") : t("run_update")}</h2>`;
  else if (end && end.status === "rebooting") title = `<h2>${t("run_rebooting")}</h2>`;
  else if (end && end.status === "window") title = `<h2>${t("run_window")}</h2>`;
  else {
    title = `<h2>${end ? t("run_done") : t("run_aborted")}</h2>${rep ? `<span class="muted">${esc(cleanSubj(rep.subject))}</span>` : ""}`;
    cls = end && end.status === "ok" && !(rep && +rep.problems) ? "done-ok" : "done-bad";
  }
  const res = resultRows(r.events);
  return `<section class="card run ${cls}"><div class="chead"><div class="ttl">${title}<span class="id">${esc(r.id)}</span></div>
      ${r.done ? `<div class="actions"><button class="btn ghost sm icon" data-act="closerun" title="${t("close")}" aria-label="${t("close")}">${icon("x")}</button></div>` : ""}</div>
    <div class="body"><div class="results">${res || `<div class="r faint">${t("waiting")}</div>`}</div>
      <div class="lines" id="runlines">${logLines(r.events, 300)}</div></div></section>`;
}

// ------------------------------------------------------------------ history
function targetTxt(only) { return only ? only.replace(/node:/g, "Node ") : t("all_selected"); }
function renderHistory() {
  const h = S.history;
  const refresh = `<button class="btn" data-act="reloadhist">${icon("refresh")}${t("refresh")}</button>`;
  if (!h) return phead(t("history")) + skeleton(6);
  if (!h.length) return `${phead(t("history"))}<section class="card"><div class="empty"><div class="ring idle">${icon("clock")}</div>
    <b>${t("no_history")}</b><p>${t("no_history_p")}</p><a class="btn" href="#/overview">${t("go_overview")}</a></div></section>`;
  const rows = h.map(r => {
    const ts = r.start || runTs(r.id);
    return `<tr data-act="detail" data-v="${esc(r.id)}" tabindex="0">
      <td class="two nw">${esc(fmt(ts))}<small>${esc(ago(ts))}</small></td>
      <td class="nw">${kindTxt(r.mode)}</td>
      <td class="hide-s">${esc(targetTxt(r.only))}</td>
      <td>${runStatusBadge(r.status, r.problems)}${r.subject ? `<span class="subj">${esc(cleanSubj(r.subject))}</span>` : ""}
        ${r.postcheck ? `<small class="subj">${t("post")}: Nodes ${esc(r.postcheck.nodes)}, ${esc(r.postcheck.guests)}</small>` : ""}</td>
      <td class="hide-m nw">${r.trigger === "ui" ? t("by_ui") : t("by_cli")}</td></tr>`;
  }).join("");
  return `${phead(t("history"), esc(t("sub_history", { n: h.length })), refresh)}
    <section class="card"><div class="tblwrap"><table class="tbl click"><thead><tr><th>${t("h_when")}</th><th>${t("h_kind")}</th><th class="hide-s">${t("h_target")}</th><th>${t("h_result")}</th><th class="hide-m">${t("h_by")}</th></tr></thead>
    <tbody>${rows}</tbody></table></div></section>`;
}
function renderDetail() {
  const d = S.detail;
  const back = `<a class="btn ghost icon" href="#/history" title="${t("back")}" aria-label="${t("back")}">${icon("back")}</a>`;
  if (d.loading) return `<div class="phead"><div class="ttl">${back}<h1>${t("history")}</h1></div></div>${skeleton(2)}${skeleton(4)}`;
  const st = d.events.find(e => e.ev === "start") || {};
  const rep = d.events.find(e => e.ev === "report");
  const end = d.events.find(e => e.ev === "end");
  const t0 = st.ts || runTs(d.id);
  const log = d.events.filter(e => e.ev === "log").map(e => esc(clock(e.ts) + "  " + e.msg)).join("\n");
  const res = resultRows(d.events);
  return `<div class="phead"><div class="ttl">${back}<h1>${st.mode === "dryrun" ? t("k_check") : t("k_update")} · ${esc(fmt(t0))}</h1>
      ${end ? runStatusBadge(end.status, rep && rep.problems) : runStatusBadge("aborted")}</div>
      ${rep ? `<p class="muted">${esc(cleanSubj(rep.subject))}</p>` : ""}</div>
    <section class="card"><dl class="kv"><div><dt>${t("h_target")}</dt><dd>${esc(targetTxt(st.only))}</dd></div>
      <div><dt>${t("h_by")}</dt><dd>${st.trigger === "ui" ? t("by_ui") : t("by_cli")}</dd></div>
      <div><dt>Nodes</dt><dd>${esc(st.nodes || "-")}</dd></div>
      <div><dt>${t("duration")}</dt><dd>${end && t0 ? esc(dur(end.ts - t0)) : "-"}</dd></div></dl></section>
    <section class="card">${chead(t("results"), d.events.filter(e => e.ev === "result").length || null)}
      <div class="results">${res || `<div class="r faint">${t("no_results")}</div>`}</div></section>
    <section class="card">${chead(t("events"))}<pre class="log">${log || "-"}</pre></section>`;
}

// ------------------------------------------------------------------ dialogs
let lastFocus = null;
function openModal(html, focusSel) {
  const m = $("#modal");
  lastFocus = document.activeElement;
  m.innerHTML = `<div class="box" role="dialog" aria-modal="true" aria-labelledby="m-title">${html}</div>`;
  m.classList.remove("hidden");
  const f = m.querySelector(focusSel) || m.querySelector("button");
  if (f) f.focus();
}
function closeModal() {
  const m = $("#modal");
  if (m.classList.contains("hidden")) return false;
  m.classList.add("hidden"); m.innerHTML = "";
  if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
  return true;
}
function errText(r) { return (r && r.data && (r.data.detail || r.data.error)) || (r && r.status) || ""; }

function openStart(mode, targetSpec, rebootPreset) {
  const inv = S.inv, c = inv.config || {};
  let targets = [], names = [];
  if (targetSpec === "picked") targets = [...S.picked];
  else if (targetSpec) targets = [isNaN(targetSpec) ? targetSpec : +targetSpec];
  for (const x of targets) {
    if (String(x).startsWith("node:")) names.push("Node " + String(x).slice(5));
    else { const g = inv.guests.find(g => g.id === x); names.push(g ? `${g.type === "qemu" ? "VM" : "CT"} ${g.id} (${g.name})` : String(x)); }
  }
  const hasNode = !targets.length ? c.UPDATE_HOSTS === "1" : targets.some(x => String(x).startsWith("node:"));
  const defReboot = rebootPreset === "yes" || (hasNode ? c.REBOOT_HOSTS === "1" : c.REBOOT_GUESTS === "1");
  const outside = mode === "update" && c.UPDATE_WINDOW && !inv.in_window;
  openModal(`<h3 id="m-title">${mode === "check" ? t("m_check_t") : t("m_update_t")}</h3>
    <p>${mode === "check" ? t("m_check_p") : t("m_update_p")}</p>
    <ul class="targets">${targets.length ? names.map(n => `<li>${esc(n)}</li>`).join("") : `<li>${t("m_all")}</li>`}</ul>
    ${mode === "update" ? `<label class="opt"><input type="checkbox" id="o-reboot" ${defReboot ? "checked" : ""}><span>${hasNode ? t("allow_reboot_node") : t("allow_reboot")}</span></label>` : ""}
    ${outside ? note("warn", "alert", esc(t("outside_window", { w: c.UPDATE_WINDOW }))) + `<label class="opt"><input type="checkbox" id="o-force"><span>${t("force_window")}</span></label>` : ""}
    <div class="bt"><button class="btn" data-act="mclose">${t("cancel")}</button>
      <button class="btn primary" id="m-go" ${outside ? "disabled" : ""}>${t("start")}</button></div>`, outside ? "#o-force" : "#m-go");
  const force = $("#o-force");
  if (force) force.addEventListener("change", () => { $("#m-go").disabled = !force.checked; });
  $("#m-go").addEventListener("click", async () => {
    const body = { mode, targets };
    if (mode === "update") body.reboot = $("#o-reboot").checked ? "yes" : "no";
    if (outside) body.ignore_window = true;
    $("#m-go").disabled = true;
    try {
      const r = await api("/api/start", { body });
      closeModal();
      if (r.ok) { S.picked.clear(); attachRun(r.data.run, mode === "check" ? "dryrun" : "live"); window.scrollTo({ top: 0, behavior: "smooth" }); }
      else toast(r.data && r.data.error === "already running" ? t("already_running") : t("failed_start") + ": " + errText(r), "err");
    } catch (e) { closeModal(); }
  });
}

// ------------------------------------------------------------------ settings (mail)
const MAIL_KEYS = ["MAIL_THEME", "NOTIFY", "MAIL_TO", "MAIL_TRANSPORT", "MAIL_FROM", "TITLE", "SMTP_HOST", "SMTP_PORT", "SMTP_SECURITY", "SMTP_USER"];
function initForm() {
  const c = (S.inv && S.inv.config) || {};
  S.form = {};
  for (const k of MAIL_KEYS) S.form[k] = c[k] != null ? c[k] : "";
  S.form.MAIL_THEME = S.form.MAIL_THEME === "dark" ? "dark" : "light";
  S.form.NOTIFY = S.form.NOTIFY || "errors";
  S.form.MAIL_TRANSPORT = S.form.MAIL_TRANSPORT || "system";
  S.form.SMTP_PORT = S.form.SMTP_PORT || "587";
  S.form.SMTP_SECURITY = S.form.SMTP_SECURITY || "starttls";
  S.form.SMTP_PASS = "";
  S.setMsg = null;
}
function mailHint() {
  const c = (S.inv && S.inv.config) || {};
  if (!S.inv || c.NOTIFY !== "never" || !canWrite()) return "";
  return note("warn", "mail", t("mail_off_hint"), `<a class="btn sm" href="#/settings">${t("mail_set_up")}</a>`);
}
function renderSettings() {
  const head = phead(t("settings"), t("sub_settings"));
  if (!S.inv) return head + skeleton(6);
  if (!S.form) initForm();
  const f = S.form, w = canWrite(), dis = w && !S.busy ? "" : "disabled";
  const on = f.NOTIFY !== "never", smtp = on && f.MAIL_TRANSPORT === "smtp";
  const opt = (v, cur, label) => `<option value="${v}" ${v === cur ? "selected" : ""}>${esc(label)}</option>`;
  const fld = (k, label, type, ph) => `<label class="field"><span>${label}</span><input id="f-${k}" data-f="${k}" type="${type || "text"}" value="${esc(f[k])}"
    ${ph ? `placeholder="${esc(ph)}"` : ""} ${dis} autocomplete="${type === "password" ? "new-password" : "off"}"></label>`;
  const sel = (k, label, opts) => `<label class="field"><span>${label}</span><select id="f-${k}" data-f="${k}" ${dis}>${opts.map(o => opt(o[0], f[k], o[1])).join("")}</select></label>`;
  const passPh = S.inv.smtp_pass_set ? t("set_pass_kept") : "";
  const msg = S.setMsg ? note(S.setMsg.ok ? "ok" : "err", S.setMsg.ok ? "check" : "alert",
    esc(S.setMsg.text) + (S.setMsg.detail ? `<pre class="log">${esc(S.setMsg.detail)}</pre>` : "")) : "";
  const mail = `<section class="card">${chead(t("set_mail"))}
    <form id="setform" class="cbody" autocomplete="off"><p class="lead">${t("set_mail_sub")}</p>
      ${sel("MAIL_THEME", t("mail_theme"), [["light", t("th_light")], ["dark", t("th_dark")]])}
      ${sel("NOTIFY", t("set_notify"), [["never", t("n_never")], ["errors", t("n_errors")], ["changes", t("n_changes")], ["always", t("n_always")]])}
      ${on ? `${fld("MAIL_TO", t("set_to"), "text", t("set_to_ph"))}
        ${sel("MAIL_TRANSPORT", t("set_transport"), [["system", t("tr_system")], ["smtp", t("tr_smtp")]])}
        ${smtp ? `<div class="grid2">${fld("SMTP_HOST", t("set_host"), "text", "smtp.gmail.com")}${fld("SMTP_PORT", t("set_port"), "text")}</div>
          ${sel("SMTP_SECURITY", t("set_sec"), [["starttls", t("sec_starttls")], ["ssl", t("sec_ssl")], ["none", t("sec_none")]])}
          <div class="grid2">${fld("SMTP_USER", t("set_user"), "text")}${fld("SMTP_PASS", t("set_pass"), "password", passPh)}</div>` : ""}
        <div class="grid2">${fld("MAIL_FROM", t("set_from"), "text")}${fld("TITLE", t("set_title"), "text")}</div>` : ""}
      ${msg}
      <div class="btnrow"><button type="button" class="btn primary" data-act="savemail" ${dis}>${S.busy ? '<span class="spin"></span>' : ""}${t("set_save")}</button>
        ${on ? `<button type="button" class="btn" data-act="savemailtest" ${dis}>${icon("mail")}${t("set_save_test")}</button>` : ""}</div>
    </form></section>`;
  const sample = S.mailSample || "attention";
  const preview = `<section class="card">${chead(t("mail_preview"))}<div class="cbody">
    <label class="field"><span>${t("mail_preview")}</span><select id="mail-sample">
    ${["attention", "success", "dryrun"].map(v => opt(v, sample, t("sample_" + v))).join("")}</select></label>
    <iframe class="mail-preview" title="${t("mail_preview")}" sandbox="allow-same-origin allow-popups allow-popups-to-escape-sandbox" src="mail-preview.html#${f.MAIL_THEME}-${sample}"></iframe></div></section>`;
  const look = `<section class="card">${chead(t("appearance"))}<div class="cbody">
    <div class="optrow"><div><b>${t("theme")}</b><span>${t("theme_sub")}</span></div>${themeSwitch()}</div>
    <div class="optrow"><div><b>${t("language")}</b><span>${t("lang_sub")}</span></div>${langSelect()}</div></div></section>`;
  return `${head}${w ? "" : note("", "lock", t("set_ro"))}${updBanner()}${mailHint()}
    <div class="grid g-set"><div class="stack">${mail}${scheduleCard()}</div><div class="stack">${preview}${look}${renderUpd()}${aboutCard()}</div></div>`;
}
function scheduleCard() {   // read only here - the schedule is set in the setup wizard on the node
  const inv = S.inv, c = inv.config || {}, nr = nextRunTxt(inv.next_run);
  const win = c.UPDATE_WINDOW ? `${esc(c.UPDATE_WINDOW.replace("-", " – "))} · ${inv.in_window ? t("open_w") : t("closed_w")}` : t("no_window");
  return `<section class="card">${chead(t("schedule"))}<div class="cbody">
    <dl class="facts"><div><dt>${t("schedule")}</dt><dd>${esc(inv.schedule_text || "-")}</dd></div>
      <div><dt>${t("next_run")}</dt><dd>${esc(nr.v)}${nr.s ? ` · ${esc(nr.s)}` : ""}</dd></div>
      <div><dt>${t("window_l")}</dt><dd>${win}</dd></div></dl>
    <p class="fine">${t("sched_hint")}</p></div></section>`;
}
function aboutCard() {
  const inv = S.inv, a = (href, label) => `<a href="${href}" target="_blank" rel="noopener">${label}</a>`;
  return `<section class="card">${chead(t("about"))}<div class="cbody">
    <dl class="facts"><div><dt>pve-autoupdate</dt><dd>${esc(inv.version)}</dd></div>
      <div><dt>${t("ui_version")}</dt><dd>${esc(S.session.version)}</dd></div>
      <div><dt>${t("author")}</dt><dd>${esc(AUTHOR)}</dd></div></dl>
    <div class="links">${a(WEBSITE, "kaimazon.de")}${a(REPO_URL, "GitHub")}${a(REPO_URL + "/issues", t("report_issue"))}
      ${hasDonate() ? a(DONATE_URL, icon("heart") + t("donate")) : ""}</div></div></section>`;
}
async function saveMail(test) {
  const f = S.form;
  const on = f.NOTIFY !== "never", smtp = on && f.MAIL_TRANSPORT === "smtp";
  const fail = text => { S.setMsg = { ok: false, text }; render(); };
  if (on && !/^[^@\s,]+@[^@\s,]+\.[^@\s,]+(\s*,\s*[^@\s,]+@[^@\s,]+\.[^@\s,]+)*$/.test(f.MAIL_TO.trim())) return fail(t("need_to"));
  if (smtp && !f.SMTP_HOST.trim()) return fail(t("need_host"));
  if (smtp && !(+f.SMTP_PORT >= 1 && +f.SMTP_PORT <= 65535)) return fail(t("need_port"));
  const body = { NOTIFY: f.NOTIFY, MAIL_THEME: f.MAIL_THEME };
  if (on) {
    Object.assign(body, { MAIL_TO: f.MAIL_TO.trim(), MAIL_TRANSPORT: f.MAIL_TRANSPORT, MAIL_FROM: f.MAIL_FROM.trim(), TITLE: f.TITLE.trim() });
    if (smtp) {
      Object.assign(body, { SMTP_HOST: f.SMTP_HOST.trim(), SMTP_PORT: String(f.SMTP_PORT).trim(), SMTP_SECURITY: f.SMTP_SECURITY, SMTP_USER: f.SMTP_USER.trim() });
      if (f.SMTP_PASS) body.SMTP_PASS = f.SMTP_PASS;
    }
  }
  S.busy = true; S.setMsg = null; render();
  let msg = null;
  try {
    const r = await api("/api/config", { body });
    if (!r.ok) { msg = { ok: false, text: t("set_err") + ": " + ((r.data && (r.data.error || r.data.detail)) || r.status) }; }
    else {
      await loadInventory();
      msg = { ok: true, text: t("set_saved") };
      if (test) {
        S.setMsg = { ok: true, text: t("sending") }; render();
        const tr = await api("/api/test-mail", { body: {} });
        msg = tr.ok && tr.data.ok ? { ok: true, text: t("set_test_ok") } : { ok: false, text: t("set_test_fail"), detail: (tr.data && tr.data.output) || "" };
      }
      initForm();
    }
  } catch (e) { if (e.message !== "login") msg = { ok: false, text: t("set_err") }; }
  S.busy = false; S.setMsg = msg; render();
}

// ------------------------------------------------------------------ program updates
function updBanner() {
  const inv = S.inv;
  if (S.updating) return note("accent", "up", `<span class="spin"></span> ${t("upd_running")}`);
  if (!inv || !inv.update_available) return "";
  const notes = (inv.update_notes || []).map(l => `<li>${esc(l.replace(/^\s*[-*]\s*/, ""))}</li>`).join("");
  return note("accent", "up", `<b>${esc(t("upd_title", { v: inv.latest_version }))}</b> <span class="muted">· ${esc(t("upd_installed", { v: inv.version }))}</span>
      ${notes ? `<details><summary>${t("upd_whatsnew")}</summary><ul>${notes}</ul></details>` : ""}`,
    canWrite() ? `<button class="btn sm primary" data-act="selfupdate">${t("upd_now")}</button>` : "");
}
function renderUpd() {
  const inv = S.inv, w = canWrite(), busy = S.upd && S.upd.busy;
  const ts = +inv.update_checked;
  const checked = ts ? `${fmt(ts)} · ${ago(ts)}` : t("upd_none");
  let state = "";
  if (busy) state = `<p class="updstate"><span class="spin"></span>${t("upd_checking")}</p>`;
  else if (inv.update_available) state = `<p class="updstate new">${icon("up")}<b>${esc(t("upd_title", { v: inv.latest_version }))}</b></p>`;
  else if (inv.update_error) state = `<p class="updstate warn">${icon("alert")}${t("upd_unreach")}</p>`;
  else if (ts) state = `<p class="updstate">${icon("check")}${t("upd_uptodate")}</p>`;
  return `<section class="card">${chead(t("upd_section"))}<div class="cbody">
    <dl class="facts"><div><dt>${t("upd_installed_l")}</dt><dd>${esc(inv.version)}</dd></div>
      <div><dt>${t("upd_latest_l")}</dt><dd>${esc(inv.latest_version || "-")}</dd></div>
      <div><dt>${t("upd_checked_l")}</dt><dd>${esc(checked)}</dd></div></dl>
    ${state}
    <div class="btnrow"><button type="button" class="btn" data-act="updcheck" ${busy || S.updating ? "disabled" : ""}>${icon("refresh")}${t("upd_check")}</button>
      ${w && inv.update_available ? `<button type="button" class="btn primary" data-act="selfupdate" ${S.updating ? "disabled" : ""}>${t("upd_now")}</button>` : ""}</div>
    <p class="fine">${t("upd_hint_cli")}</p></div></section>`;
}
async function updCheck() {
  S.upd = { busy: true }; render();
  try { await api("/api/update-check", { body: { force: true } }); await loadInventory(); } catch (e) { /* login */ }
  S.upd = null; render();
}
function openSelfUpdate() {
  const inv = S.inv;
  openModal(`<h3 id="m-title">${t("upd_confirm_t")}</h3>
    <p>${esc(t("upd_confirm_p", { v: inv.latest_version }))}</p>
    <div class="bt"><button class="btn" data-act="mclose">${t("cancel")}</button><button class="btn primary" id="m-upd">${t("upd_now")}</button></div>`, "#m-upd");
  $("#m-upd").addEventListener("click", async () => {
    $("#m-upd").disabled = true;
    let r = null;
    try { r = await api("/api/update-start", { body: {} }); } catch (e) { /* login */ }
    closeModal();
    if (!r || !r.ok) { toast(t("upd_failed") + ": " + errText(r), "err"); return; }
    S.updating = { from: inv.version, t0: Date.now() }; render(); waitForUpdate();
  });
}
function waitForUpdate() {   // the web UI restarts during the update - wait for the new version, then reload
  clearInterval(pollInv);
  const tick = async () => {
    if (Date.now() - S.updating.t0 > 300000) { location.reload(); return; }
    try {
      const r = await fetch("/api/inventory", { credentials: "same-origin" });
      if (r.status === 401) { location.reload(); return; }
      if (r.ok) { const d = await r.json(); if (d.version && d.version !== S.updating.from) { location.reload(); return; } }
    } catch (e) { /* web UI is restarting */ }
    setTimeout(tick, 3000);
  };
  setTimeout(tick, 5000);
}

// ------------------------------------------------------------------ polling
function attachRun(id, mode) {
  S.run = { id, from: 0, events: [], done: false, mode: mode || "live", misses: 0 };
  render();
  clearInterval(pollRun);
  pollRun = setInterval(tickRun, 2000);
  tickRun();
}
async function tickRun() {
  const r = S.run;
  if (!r || r.done) { clearInterval(pollRun); return; }
  try {
    const res = await api(`/api/events?run=${encodeURIComponent(r.id)}&from=${r.from}`);
    if (!res.ok) return;
    if (res.data.events.length) {
      r.events.push(...res.data.events); r.from = res.data.next; r.misses = 0;
      const st = r.events.find(e => e.ev === "start"); if (st) r.mode = st.mode;
    } else r.misses++;
    const ended = r.events.some(e => e.ev === "end");
    // no end event and nothing running any more -> aborted (or never started)
    if (ended || (r.misses > 5 && S.inv && !S.inv.running)) {
      r.done = true; clearInterval(pollRun);
      loadInventory(); loadHistory();
    }
    if (S.tab === "overview" || S.tab === "guests") { render(); const l = $("#runlines"); if (l) l.scrollTop = l.scrollHeight; }
  } catch (e) { /* network hiccup - next tick */ }
}
async function loadInventory() {
  try {
    const r = await api("/api/inventory");
    if (r.ok) {
      S.inv = r.data; S.invErr = "";
      if (!S.loadedLang) { S.loadedLang = true; if (!loadPref("lang") && r.data.lang) S.lang = r.data.lang; }
      if (r.data.running && !S.run && r.data.last_run) attachRun(r.data.last_run);
    } else S.invErr = (r.data && r.data.detail) || String(r.status);
  } catch (e) { if (e.message !== "login") S.invErr = String(e.message || e); }
  if (S.session) render();
}
async function loadHistory() {
  try { const r = await api("/api/history?n=60"); if (r.ok) S.history = r.data; } catch (e) { /* ignore */ }
  if (S.session) render();
}
function stopPolling() { clearInterval(pollRun); clearInterval(pollInv); }

// ------------------------------------------------------------------ routing (#/guests, #/history/<run>)
function applyRoute() {
  const m = /^#\/([a-z]+)(?:\/([\w-]+))?$/.exec(location.hash || "");
  const tab = m && TABS.includes(m[1]) ? m[1] : "overview";
  const id = tab === "history" && m ? m[2] : null;
  if (tab !== S.tab && tab === "settings") S.form = null;
  S.tab = tab; S.menu = null;
  if (tab === "history" && id) openDetail(id);
  else { S.detail = null; if (tab === "history") loadHistory(); }
  render(); window.scrollTo(0, 0);
}
async function openDetail(id) {
  S.detail = { id, events: [], loading: true };
  const r = await api(`/api/events?run=${encodeURIComponent(id)}&from=0`).catch(() => null);
  if (S.detail && S.detail.id === id) { S.detail.events = r && r.ok ? r.data.events : []; S.detail.loading = false; render(); }
}
window.addEventListener("hashchange", () => { if (S.session) applyRoute(); });

// ------------------------------------------------------------------ render + events
function render() {
  document.documentElement.lang = S.lang;
  applyTheme();
  const app = $("#app");
  const q = document.activeElement && document.activeElement.id === "q";
  const pos = q ? document.activeElement.selectionStart : 0;
  const ae = document.activeElement, fid = ae && ae.id && ae.id.startsWith("f-") ? ae.id : null;
  const fpos = fid && ae.selectionStart != null ? ae.selectionStart : null;
  const y = window.scrollY;
  app.innerHTML = S.session ? renderApp() : renderLogin();
  window.scrollTo(0, y);
  if (q) { const el = $("#q"); if (el) { el.focus(); el.setSelectionRange(pos, pos); } }
  if (fid) { const el = document.getElementById(fid); if (el) { el.focus(); if (fpos != null) { try { el.setSelectionRange(fpos, fpos); } catch (e) { /* select/password */ } } } }
  const fl = $("#f-login");
  if (fl) fl.addEventListener("submit", ev => { ev.preventDefault(); doLogin({ username: $("#user").value, password: $("#pw").value, realm: $("#realm").value }); });
  const ft = $("#f-tfa");
  if (ft) ft.addEventListener("submit", ev => { ev.preventDefault(); doLogin({ pending: S.tfa, code: $("#code").value.trim() }); });
  const sf = $("#setform");
  if (sf) sf.addEventListener("submit", ev => { ev.preventDefault(); if (canWrite() && !S.busy) saveMail(false); });
  const qs = $("#q");
  if (qs) qs.addEventListener("input", () => { S.q = qs.value; render(); });
}

document.addEventListener("click", async ev => {
  if (ev.target.id === "modal") { closeModal(); return; }   // click on the backdrop
  const el = ev.target.closest("[data-act]");
  // any click outside an open dropdown (or on one of its items) closes it
  if (S.menu && (!ev.target.closest(".mwrap") || (el && el.dataset.act !== "menu"))) { S.menu = null; render(); }
  if (!el) return;
  const a = el.dataset.act, v = el.dataset.v;
  if (a === "menu") {
    S.menu = S.menu === v ? null : v; render();
    const first = document.querySelector(".menu button"); if (first && ev.detail === 0) first.focus();
  }
  else if (a === "theme") { S.theme = v; savePref("theme", v); render(); }
  else if (a === "logout") { await api("/api/logout", { body: {} }).catch(() => {}); S.session = null; stopPolling(); render(); }
  else if (a === "filter") { S.filter = v; savePref("filter", v); render(); }
  else if (a === "pick") { const id = +v; if (el.checked) S.picked.add(id); else S.picked.delete(id); render(); }
  else if (a === "pickall") { const l = visibleGuests(); if (el.checked) l.forEach(g => S.picked.add(g.id)); else l.forEach(g => S.picked.delete(g.id)); render(); }
  else if (a === "clearsel") { S.picked.clear(); render(); }
  else if (a === "go") openStart(el.dataset.mode, el.dataset.t, el.dataset.reboot);
  else if (a === "mclose") closeModal();
  else if (a === "closerun") { S.run = null; render(); }
  else if (a === "detail") location.hash = "#/history/" + v;
  else if (a === "reloadhist") loadHistory();
  else if (a === "savemail") saveMail(false);
  else if (a === "savemailtest") saveMail(true);
  else if (a === "updcheck") updCheck();
  else if (a === "selfupdate") openSelfUpdate();
});
document.addEventListener("input", ev => {
  const k = ev.target.dataset && ev.target.dataset.f;
  if (k && S.form) S.form[k] = ev.target.value;
});
document.addEventListener("change", ev => {
  const el = ev.target, k = el.dataset && el.dataset.f;
  if (el.matches && el.matches("[data-langsel]")) { S.lang = el.value; savePref("lang", el.value); render(); }
  else if (el.id === "mail-sample") { S.mailSample = el.value; render(); }
  else if (k && S.form && el.tagName === "SELECT") { S.form[k] = el.value; render(); }
});
document.addEventListener("keydown", ev => {
  if (ev.key === "Escape") {
    if (!closeModal() && S.menu) { const k = S.menu; S.menu = null; render(); const b = document.querySelector(`[data-act="menu"][data-v="${CSS.escape(k)}"]`); if (b) b.focus(); }
  }
  else if ((ev.key === "Enter" || ev.key === " ") && ev.target.matches && ev.target.matches("tr[data-act], li[data-act]")) { ev.preventDefault(); ev.target.click(); }
});

async function boot() {
  const r = await api("/api/session").catch(() => null);
  if (r && r.ok) {
    S.session = r.data; S.busy = false; S.loginErr = "";
    applyRoute();
    loadInventory(); if (S.tab !== "history") loadHistory();
    clearInterval(pollInv);
    pollInv = setInterval(() => { if (!document.hidden) { loadInventory(); if (S.tab === "history" && !S.detail) loadHistory(); } }, 15000);
  } else {
    S.session = null;
    if (r && r.data) S.node = r.data.node;
    render();
    const rr = await api("/api/realms").catch(() => null);
    if (rr && rr.ok) { S.realms = rr.data; render(); }
  }
}
boot();
