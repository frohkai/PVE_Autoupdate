/* pve-autoupdate web UI - plain JavaScript, no libraries (works offline in the LAN) */
"use strict";

const AUTHOR = "Kai Frohwerk";
const WEBSITE = "https://kaimazon.de";
const REPO_URL = "https://github.com/frohkai/PVE_Autoupdate";
const DONATE_URL = "https://liberapay.com/__LIBERAPAY_USER__/donate";
const hasDonate = () => DONATE_URL.startsWith("http") && !DONATE_URL.includes("__");

// ------------------------------------------------------------------ texts
const TXT = {
  en: {
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
    overview: "Overview", history: "History", log: "Log", logout: "Sign out", read_only: "read only",
    ro_banner: "Your account can view, but not start updates (Sys.Modify needed).",
    schedule: "Schedule", next_run: "Next run", last_run: "Last run", state: "Status",
    window_open: "update window open", window_closed: "outside the update window", no_window: "no time window",
    idle: "Ready", running: "Update running", reboot_pending: "Node reboot pending (post check follows)",
    never: "never", nodes: "Nodes", guests: "Containers & VMs",
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
    log_title: "Log on the node", log_empty: "The log is empty.", pkgs: "{n} pkg", post: "Post check",
    s_running: "Running", s_ok: "OK", s_fail: "Errors", s_aborted: "Aborted", s_rebooting: "Rebooting", s_window: "Outside window", s_problems: "With problems",
    b_OK: "OK", b_WARN: "Warning", b_FAIL: "Failed", b_ROLLBACK: "Rolled back", b_SKIP: "Skipped", b_TEST: "Checked", b_RUN: "Running",
    ago_s: "just now", ago_m: "{n} min ago", ago_h: "{n} h ago", ago_d: "{n} d ago", in_x: "in {x}",
    up_to_date: "up to date", reboot_needed: "reboot needed",
    os_windows: "Windows", os_linux: "Linux", main_nav: "Main", language: "Language",
  },
  de: {
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
    overview: "Übersicht", history: "Verlauf", log: "Protokoll", logout: "Abmelden", read_only: "nur lesen",
    ro_banner: "Dein Konto darf alles sehen, aber keine Updates starten (Sys.Modify nötig).",
    schedule: "Zeitplan", next_run: "Nächster Lauf", last_run: "Letzter Lauf", state: "Status",
    window_open: "Zeitfenster offen", window_closed: "außerhalb des Zeitfensters", no_window: "kein Zeitfenster",
    idle: "Bereit", running: "Update läuft", reboot_pending: "Node-Neustart läuft (Nachkontrolle folgt)",
    never: "noch nie", nodes: "Nodes", guests: "Container & VMs",
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
    log_title: "Protokoll auf dem Node", log_empty: "Das Protokoll ist leer.", pkgs: "{n} Pak.", post: "Nachkontrolle",
    s_running: "Läuft", s_ok: "OK", s_fail: "Fehler", s_aborted: "Abgebrochen", s_rebooting: "Neustart", s_window: "Außerhalb Zeitfenster", s_problems: "Mit Problemen",
    b_OK: "OK", b_WARN: "Warnung", b_FAIL: "Fehler", b_ROLLBACK: "Zurückgesetzt", b_SKIP: "Übersprungen", b_TEST: "Geprüft", b_RUN: "Läuft",
    ago_s: "gerade eben", ago_m: "vor {n} Min.", ago_h: "vor {n} Std.", ago_d: "vor {n} Tg.", in_x: "in {x}",
    up_to_date: "aktuell", reboot_needed: "Neustart nötig",
    os_windows: "Windows", os_linux: "Linux", main_nav: "Hauptmenü", language: "Sprache",
  },
};

// ------------------------------------------------------------------ state
const S = {
  lang: loadPref("lang") || ((navigator.language || "en").slice(0, 2) === "de" ? "de" : "en"),
  session: null, inv: null, invErr: "", history: null, tab: "overview",
  filter: loadPref("filter") || "all", q: "", picked: new Set(),
  run: null,            // {id, from, events, done, mode}
  detail: null,         // {id, events, loading}
  logText: null, loginErr: "", tfa: null, busy: false,
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
};
function icon(n) { return `<svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path d="${ICONS[n]}"/></svg>`; }

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
  return new Date(ts * 1000).toLocaleString(S.lang === "de" ? "de-DE" : "en-GB", { dateStyle: "medium", timeStyle: "short" });
}
function runTs(id) {   // 20261021-030000 -> unix ts (node local time ~ browser local time)
  const m = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})$/.exec(id || "");
  return m ? new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() / 1000 : 0;
}
function nextRunTxt(s) {
  if (!s || /not scheduled|nicht geplant/.test(s)) return { v: s || "-", s: "" };
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
function osTag(g) {   // one tag per guest: kind + OS ("CT · debian", "VM · Windows")
  const os = (g.os || "").toLowerCase(), kind = g.type === "qemu" ? "VM" : "CT";
  if (os.startsWith("w")) return `<span class="tag win">${kind} · ${t("os_windows")}</span>`;
  if (!os) return `<span class="tag">${kind}</span>`;
  if (os === "l26" || os === "l24") return `<span class="tag">${kind} · ${t("os_linux")}</span>`;
  return `<span class="tag">${kind} · ${esc(os)}</span>`;
}
function resultCell(r, slot) {
  if (!r || !r[slot]) return `<span class="faint">${t("none_yet")}</span>`;
  const x = r[slot];
  let sum = x.summary || "";
  if (x.reboot) sum += " · " + t("reboot_needed");
  return `<div class="rc" title="${esc(fmt(x.ts) + " - " + sum)}">${badge(x.status)}<span>${esc(sum)}</span><small>${esc(ago(x.ts))}</small></div>`;
}
function skeleton(lines) { return `<div class="panel sk-block" aria-busy="true">${'<span class="sk"></span>'.repeat(lines || 3)}</div>`; }
function sect(title, count, actions) {
  return `<div class="sect"><h2>${title}</h2>${count != null ? `<span class="count">${count}</span>` : ""}${actions ? `<div class="actions">${actions}</div>` : ""}</div>`;
}
function note(kind, ic, html, act) {
  return `<div class="note ${kind}">${icon(ic)}<div class="txt">${html}</div>${act ? `<div class="act">${act}</div>` : ""}</div>`;
}
function lastOf(kind, id) { return (S.inv && S.inv.last && S.inv.last[kind + ":" + id]) || null; }
const canWrite = () => S.session && S.session.write;
const isRunning = () => (S.inv && S.inv.running) || (S.run && !S.run.done);

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
  return `<main class="login"><div class="card">
    <img class="biglogo" src="logo.svg" alt="PVE Autoupdate" width="440" height="399">
    <div class="panel">
      <h1>${t("login_title")}</h1>
      <p class="sub">${t("login_sub")}${S.node ? ` · <span class="mono">${esc(S.node)}</span>` : ""}</p>
      ${form}
    </div>
    <div class="foot"><span>by ${esc(AUTHOR)} · <a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a></span>${langSwitch()}</div>
  </div></main>`;
}
function langSwitch() {
  const b = v => `<button type="button" data-act="lang" data-v="${v}" class="${S.lang === v ? "on" : ""}" aria-pressed="${S.lang === v}">${v.toUpperCase()}</button>`;
  return `<div class="seg lang" role="group" aria-label="${t("language")}">${b("en")}${b("de")}</div>`;
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

// ------------------------------------------------------------------ app shell
function renderApp() {
  const inv = S.inv;
  const where = inv ? (inv.cluster ? "Cluster " + inv.cluster : "Node " + inv.self) : (S.session.node || "");
  const tab = k => `<button class="tab ${S.tab === k ? "on" : ""}" data-act="tab" data-v="${k}" ${S.tab === k ? 'aria-current="page"' : ""}>${t(k)}</button>`;
  let body = "";
  if (S.tab === "overview") body = renderOverview();
  else if (S.tab === "history") body = S.detail ? renderDetail() : renderHistory();
  else if (S.tab === "settings") body = renderSettings();
  else body = renderLog();
  return `<header class="top"><div class="in">
      <div class="brand"><img src="emblem.svg" alt="" width="240" height="177"><b>pve-autoupdate</b></div>
      <nav class="tabs" aria-label="${t("main_nav")}">${tab("overview")}${tab("history")}${tab("settings")}${tab("log")}</nav>
      <div class="right">
        <div class="who"><b title="${esc(S.session.user)}">${esc(S.session.user)}</b>
          <span>${esc(where)}${canWrite() ? "" : ` · ${icon("lock")}${t("read_only")}`}</span></div>
        ${langSwitch()}
        <button class="btn ghost icon" data-act="logout" title="${t("logout")}" aria-label="${t("logout")}">${icon("logout")}</button>
      </div>
    </div></header>
    <main>${S.invErr ? note("err", "alert", `<b>${t("node_down")}</b> · ${esc(S.invErr)}`) : ""}
      ${canWrite() || S.tab === "settings" ? "" : note("", "lock", t("ro_banner"))}${updBanner()}${mailHint()}${body}</main>
    <footer><span class="grow">pve-autoupdate ${esc(inv ? inv.version : "")} · UI ${esc(S.session.version)}</span>
      <span>by ${esc(AUTHOR)}</span>
      <a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a>
      <a href="${REPO_URL}" target="_blank" rel="noopener">GitHub</a>
      ${hasDonate() ? `<a href="${DONATE_URL}" target="_blank" rel="noopener">${icon("heart")}Liberapay</a>` : ""}</footer>`;
}

// ------------------------------------------------------------------ overview
function renderOverview() {
  const inv = S.inv;
  if (!inv) return skeleton(3) + sect(t("nodes")) + skeleton(2);
  const c = inv.config || {};
  const nr = nextRunTxt(inv.next_run);
  const win = c.UPDATE_WINDOW ? `${c.UPDATE_WINDOW.replace("-", " – ")} · ${inv.in_window ? t("window_open") : t("window_closed")}` : t("no_window");
  const last = (S.history && S.history[0]) || null;
  let state = `<span class="dot on"></span>${t("idle")}`;
  if (isRunning()) state = `<span class="spin"></span>${t("running")}`;
  else if (inv.reboot_pending) state = `<span class="dot wait"></span>${t("reboot_pending")}`;
  const lastHtml = last
    ? `<div class="v">${runStatusBadge(last.status, last.problems)}${esc(last.mode === "dryrun" ? t("k_check") : t("k_update"))}</div>
       <div class="s" title="${esc(cleanSubj(last.subject))}">${esc(ago(last.start || runTs(last.id)))}${last.subject ? " · " + esc(cleanSubj(last.subject)) : ""}</div>`
    : `<div class="v">${t("never")}</div>`;

  const w = canWrite(), dis = isRunning() ? "disabled" : "";
  const summary = `<dl class="panel summary">
    <div class="state"><dt>${t("state")}</dt><dd><div class="v">${state}</div><div class="s">${esc(win)}</div></dd></div>
    <div><dt>${t("schedule")}</dt><dd><div class="v" title="${esc(c.SCHEDULE || "")}">${esc(inv.schedule_text || "-")}</div><div class="s mono">${esc(c.SCHEDULE || "")}</div></dd></div>
    <div><dt>${t("next_run")}</dt><dd><div class="v">${esc(nr.v)}</div><div class="s">${esc(nr.s)}</div></dd></div>
    <div><dt>${t("last_run")}</dt><dd>${lastHtml}</dd></div></dl>`;

  const nodes = inv.nodes.map(n => {
    const l = lastOf("NODE", n.name);
    return `<div class="node">
      <div class="nm"><span class="dot ${n.online ? "on" : "off"}" title="${n.online ? t("online") : t("offline")}"></span>
        <div><b>${esc(n.name)}</b> ${n.name === inv.self ? `<span class="tag" title="${t("ui_node")}">UI</span>` : ""}<span class="ip">${esc(n.ip)}</span></div></div>
      <dl class="res"><dt>${t("last_check")}</dt><dd>${resultCell(l, "check")}</dd></dl>
      <dl class="res"><dt>${t("last_update")}</dt><dd>${resultCell(l, "update")}</dd></dl>
      ${w ? `<div class="bt"><button class="btn sm" data-act="go" data-mode="check" data-t="node:${esc(n.name)}" ${dis}>${t("check")}</button>
        <button class="btn sm" data-act="go" data-mode="update" data-t="node:${esc(n.name)}" ${dis}>${t("update")}</button>
        <button class="btn sm danger" data-act="go" data-mode="update" data-reboot="yes" data-t="node:${esc(n.name)}" ${dis}>${t("update_reboot")}</button></div>` : ""}
    </div>`;
  }).join("");

  const allActs = w ? `<button class="btn sm" data-act="go" data-mode="check" ${dis}>${t("check_all")}</button>
      <button class="btn sm primary" data-act="go" data-mode="update" ${dis}>${t("update_all")}</button>` : "";
  return `${summary}${renderRun()}
    ${sect(t("nodes"), inv.nodes.length, allActs)}
    <div class="panel nodes">${nodes}</div>
    ${renderGuests()}`;
}

function visibleGuests() {
  const q = S.q.trim().toLowerCase();
  return (S.inv.guests || []).filter(g => !g.template).filter(g => {
    if (S.filter === "lxc" && g.type !== "lxc") return false;
    if (S.filter === "qemu" && g.type !== "qemu") return false;
    if (S.filter === "auto" && !g.selected) return false;
    return !q || String(g.id).includes(q) || (g.name || "").toLowerCase().includes(q);
  });
}

function renderGuests() {
  const all = (S.inv.guests || []).filter(g => !g.template);
  const list = visibleGuests();
  const w = canWrite(), dis = isRunning() ? "disabled" : "";
  const seg = (k, l) => `<button type="button" data-act="filter" data-v="${k}" class="${S.filter === k ? "on" : ""}" aria-pressed="${S.filter === k}">${l}</button>`;
  const picked = [...S.picked].filter(id => all.some(g => g.id === id));
  const allPicked = list.length > 0 && list.every(g => S.picked.has(g.id));
  const rows = list.map(g => {
    const kind = g.type === "qemu" ? "VM" : "LXC";
    const l = lastOf(kind, g.id);
    return `<tr class="${S.picked.has(g.id) ? "picked" : ""}">
      ${w ? `<td class="chk"><input type="checkbox" data-act="pick" data-v="${g.id}" ${S.picked.has(g.id) ? "checked" : ""} aria-label="${esc(g.name)}"></td>` : ""}
      <td class="id hide-s">${g.id}</td>
      <td class="nm"><b>${esc(g.name)}</b><span class="idm">${g.id}</span>${osTag(g)}</td>
      <td class="hide-m">${esc(g.node)}</td>
      <td class="hide-s nw"><span class="st"><span class="dot ${g.status === "running" ? "on" : ""}"></span>${esc(g.status === "running" ? t("st_running") : t("st_stopped"))}</span></td>
      <td class="hide-s" title="${esc(g.selected ? t("auto_tip") : t("manual_tip"))}">${g.selected ? `<span class="yes">${icon("check")}<span class="sr">${t("yes")}</span></span>` : `<span class="no"><span aria-hidden="true">–</span><span class="sr">${t("no")}</span></span>`}</td>
      <td class="res hide-m">${resultCell(l, "check")}</td>
      <td class="res">${resultCell(l, "update")}</td>
      ${w ? `<td class="act"><button class="btn sm" data-act="go" data-mode="check" data-t="${g.id}" ${dis}>${t("check")}</button><button class="btn sm" data-act="go" data-mode="update" data-t="${g.id}" ${dis}>${t("update")}</button></td>` : ""}
    </tr>`;
  }).join("");
  const cols = 7 + (w ? 2 : 0);
  return `${sect(t("guests"), all.length)}
    <div class="toolbar">
      <label class="search">${icon("search")}<span class="sr">${esc(t("search"))}</span><input type="search" id="q" placeholder="${esc(t("search"))}" value="${esc(S.q)}"></label>
      <div class="seg" role="group">${seg("all", t("all"))}${seg("lxc", t("cts"))}${seg("qemu", t("vms"))}${seg("auto", t("auto_only"))}</div>
      ${w && picked.length ? `<div class="selbar"><span>${picked.length} ${t("selected")}</span>
        <button class="btn sm" data-act="go" data-mode="check" data-t="picked" ${dis}>${t("check")}</button>
        <button class="btn sm primary" data-act="go" data-mode="update" data-t="picked" ${dis}>${t("update")}</button></div>` : ""}</div>
    <div class="panel tblwrap"><table class="tbl"><thead><tr>
      ${w ? `<th class="chk"><input type="checkbox" data-act="pickall" ${allPicked ? "checked" : ""} aria-label="${t("all")}"></th>` : ""}
      <th class="hide-s">${t("id")}</th><th>${t("name")}</th><th class="hide-m">${t("node")}</th>
      <th class="hide-s">${t("status")}</th><th class="hide-s">${t("auto")}</th><th class="hide-m">${t("last_check")}</th><th>${t("last_update")}</th>${w ? `<th><span class="sr">${t("actions")}</span></th>` : ""}
    </tr></thead><tbody>${rows || `<tr><td colspan="${cols}" class="empty"><p>${all.length ? t("no_match") : t("no_guests")}</p></td></tr>`}</tbody></table></div>`;
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
  return l.map(e => `<div><span class="t">${esc(new Date(e.ts * 1000).toLocaleTimeString(S.lang === "de" ? "de-DE" : "en-GB"))}</span>${esc(e.msg)}</div>`).join("");
}
function renderRun() {
  const r = S.run;
  if (!r) return "";
  const end = r.events.find(e => e.ev === "end");
  const rep = r.events.find(e => e.ev === "report");
  let title, cls = "";
  if (!r.done) title = `<span class="spin"></span><b>${r.mode === "dryrun" ? t("run_check") : t("run_update")}</b>`;
  else if (end && end.status === "rebooting") title = `<b>${t("run_rebooting")}</b>`;
  else if (end && end.status === "window") title = `<b>${t("run_window")}</b>`;
  else {
    title = `<b>${end ? t("run_done") : t("run_aborted")}</b>${rep ? `<span class="muted">${esc(cleanSubj(rep.subject))}</span>` : ""}`;
    cls = end && end.status === "ok" && !(rep && +rep.problems) ? "done-ok" : "done-bad";
  }
  const res = resultRows(r.events);
  return `<section class="panel run ${cls}"><div class="hd"><div class="ttl">${title}<span class="id">${esc(r.id)}</span></div>
      ${r.done ? `<button class="btn ghost sm icon x" data-act="closerun" title="${t("close")}" aria-label="${t("close")}">${icon("x")}</button>` : ""}</div>
    <div class="body"><div class="results">${res || `<div class="r faint">${t("waiting")}</div>`}</div>
      <div class="lines" id="runlines">${logLines(r.events, 300)}</div></div></section>`;
}

// ------------------------------------------------------------------ history
function targetTxt(only) { return only ? only.replace(/node:/g, "Node ") : t("all_selected"); }
function renderHistory() {
  const h = S.history;
  if (!h) return sect(t("history")) + skeleton(5);
  if (!h.length) return `${sect(t("history"))}<div class="panel empty"><b>${t("no_history")}</b><p>${t("no_history_p")}</p>
    <button class="btn" data-act="tab" data-v="overview">${t("go_overview")}</button></div>`;
  const rows = h.map(r => {
    const ts = r.start || runTs(r.id);
    return `<tr data-act="detail" data-v="${esc(r.id)}" tabindex="0">
      <td class="two nw">${esc(fmt(ts))}<small>${esc(ago(ts))}</small></td>
      <td>${r.mode === "dryrun" ? t("k_check") : t("k_update")}</td>
      <td class="hide-s">${esc(targetTxt(r.only))}</td>
      <td>${runStatusBadge(r.status, r.problems)}${r.subject ? `<span class="subj">${esc(cleanSubj(r.subject))}</span>` : ""}
        ${r.postcheck ? `<small class="subj faint">${t("post")}: Nodes ${esc(r.postcheck.nodes)}, ${esc(r.postcheck.guests)}</small>` : ""}</td>
      <td class="hide-m">${r.trigger === "ui" ? t("by_ui") : t("by_cli")}</td></tr>`;
  }).join("");
  const refresh = `<button class="btn sm" data-act="reloadhist">${icon("refresh")}${t("refresh")}</button>`;
  return `${sect(t("history"), h.length, refresh)}
    <div class="panel tblwrap"><table class="tbl click"><thead><tr><th>${t("h_when")}</th><th>${t("h_kind")}</th><th class="hide-s">${t("h_target")}</th><th>${t("h_result")}</th><th class="hide-m">${t("h_by")}</th></tr></thead>
    <tbody>${rows}</tbody></table></div>`;
}
function renderDetail() {
  const d = S.detail;
  const back = `<div class="crumb"><button class="btn ghost sm" data-act="back">${icon("back")}${t("back")}</button></div>`;
  if (d.loading) return back + skeleton(2) + sect(t("results")) + skeleton(3);
  const st = d.events.find(e => e.ev === "start") || {};
  const rep = d.events.find(e => e.ev === "report");
  const end = d.events.find(e => e.ev === "end");
  const log = d.events.filter(e => e.ev === "log").map(e => esc(new Date(e.ts * 1000).toLocaleTimeString(S.lang === "de" ? "de-DE" : "en-GB") + "  " + e.msg)).join("\n");
  return `${back}
    <div class="dhead"><h2>${st.mode === "dryrun" ? t("k_check") : t("k_update")} · ${esc(fmt(st.ts || runTs(d.id)))}</h2>${end ? runStatusBadge(end.status, rep && rep.problems) : runStatusBadge("aborted")}</div>
    <dl class="kv"><div><dt>${t("h_target")}</dt><dd>${esc(targetTxt(st.only))}</dd></div>
      <div><dt>${t("h_by")}</dt><dd>${st.trigger === "ui" ? t("by_ui") : t("by_cli")}</dd></div>
      <div><dt>Nodes</dt><dd>${esc(st.nodes || "-")}</dd></div></dl>
    ${rep ? `<p class="dsubj">${esc(cleanSubj(rep.subject))}</p>` : ""}
    ${sect(t("results"))}<div class="panel results">${resultRows(d.events) || `<div class="r faint">${t("no_results")}</div>`}</div>
    ${sect(t("events"))}<pre class="log">${log || "-"}</pre>`;
}
function renderLog() {
  const refresh = `<button class="btn sm" data-act="reloadlog">${icon("refresh")}${t("refresh")}</button>`;
  if (S.logText == null) return sect(t("log_title")) + skeleton(8);
  return `${sect(t("log_title"), null, refresh)}
    ${S.logText ? `<pre class="log" id="logpre">${esc(S.logText)}</pre>` : `<div class="panel empty"><p>${t("log_empty")}</p></div>`}`;
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
  if (m.classList.contains("hidden")) return;
  m.classList.add("hidden"); m.innerHTML = "";
  if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
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
      if (r.ok) { S.picked.clear(); attachRun(r.data.run, mode === "check" ? "dryrun" : "live"); }
      else toast(r.data && r.data.error === "already running" ? t("already_running") : t("failed_start") + ": " + errText(r), "err");
    } catch (e) { closeModal(); }
  });
}

// ------------------------------------------------------------------ settings (mail)
const MAIL_KEYS = ["NOTIFY", "MAIL_TO", "MAIL_TRANSPORT", "MAIL_FROM", "TITLE", "SMTP_HOST", "SMTP_PORT", "SMTP_SECURITY", "SMTP_USER"];
function initForm() {
  const c = (S.inv && S.inv.config) || {};
  S.form = {};
  for (const k of MAIL_KEYS) S.form[k] = c[k] != null ? c[k] : "";
  S.form.NOTIFY = S.form.NOTIFY || "errors";
  S.form.MAIL_TRANSPORT = S.form.MAIL_TRANSPORT || "system";
  S.form.SMTP_PORT = S.form.SMTP_PORT || "587";
  S.form.SMTP_SECURITY = S.form.SMTP_SECURITY || "starttls";
  S.form.SMTP_PASS = "";
  S.setMsg = null;
}
function mailHint() {
  const c = (S.inv && S.inv.config) || {};
  if (S.tab !== "overview" || !S.inv || c.NOTIFY !== "never" || !canWrite()) return "";
  return note("warn", "mail", t("mail_off_hint"), `<button class="btn sm" data-act="tab" data-v="settings">${t("mail_set_up")}</button>`);
}
function renderSettings() {
  if (!S.inv) return sect(t("set_mail")) + skeleton(4);
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
  return `${w ? "" : note("", "lock", t("set_ro"))}
    ${sect(t("set_mail"))}
    <form id="setform" class="panel pad narrow" autocomplete="off"><p class="lead">${t("set_mail_sub")}</p>
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
    </form>
    ${renderUpd()}`;
}
async function saveMail(test) {
  const f = S.form;
  const on = f.NOTIFY !== "never", smtp = on && f.MAIL_TRANSPORT === "smtp";
  const fail = text => { S.setMsg = { ok: false, text }; render(); };
  if (on && !/^[^@\s,]+@[^@\s,]+\.[^@\s,]+(\s*,\s*[^@\s,]+@[^@\s,]+\.[^@\s,]+)*$/.test(f.MAIL_TO.trim())) return fail(t("need_to"));
  if (smtp && !f.SMTP_HOST.trim()) return fail(t("need_host"));
  if (smtp && !(+f.SMTP_PORT >= 1 && +f.SMTP_PORT <= 65535)) return fail(t("need_port"));
  const body = { NOTIFY: f.NOTIFY };
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
  if (!inv || !inv.update_available || S.tab !== "overview") return "";
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
  return `${sect(t("upd_section"))}<div class="panel pad narrow">
    <dl class="facts"><div><dt>${t("upd_installed_l")}</dt><dd>${esc(inv.version)}</dd></div>
      <div><dt>${t("upd_latest_l")}</dt><dd>${esc(inv.latest_version || "-")}</dd></div>
      <div><dt>${t("upd_checked_l")}</dt><dd>${esc(checked)}</dd></div></dl>
    ${state}
    <div class="btnrow"><button type="button" class="btn" data-act="updcheck" ${busy || S.updating ? "disabled" : ""}>${icon("refresh")}${t("upd_check")}</button>
      ${w && inv.update_available ? `<button type="button" class="btn primary" data-act="selfupdate" ${S.updating ? "disabled" : ""}>${t("upd_now")}</button>` : ""}</div>
    <p class="fine">${t("upd_hint_cli")}</p></div>`;
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
    if (S.tab === "overview") { render(); const l = $("#runlines"); if (l) l.scrollTop = l.scrollHeight; }
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
  try { const r = await api("/api/history?n=40"); if (r.ok) S.history = r.data; } catch (e) { /* ignore */ }
  if (S.session) render();
}
async function loadLog() {
  try { const r = await api("/api/log?n=400"); S.logText = r.ok ? r.data : ""; } catch (e) { S.logText = ""; }
  if (S.session) { render(); const p = $("#logpre"); if (p) p.scrollTop = p.scrollHeight; }
}
function stopPolling() { clearInterval(pollRun); clearInterval(pollInv); }

// ------------------------------------------------------------------ render + events
function render() {
  document.documentElement.lang = S.lang;
  const app = $("#app");
  const q = document.activeElement && document.activeElement.id === "q";
  const pos = q ? document.activeElement.selectionStart : 0;
  const ae = document.activeElement, fid = ae && ae.id && ae.id.startsWith("f-") ? ae.id : null;
  const fpos = fid && ae.selectionStart != null ? ae.selectionStart : null;
  const y = window.scrollY;
  app.innerHTML = S.session ? renderApp() : renderLogin();
  window.scrollTo(0, y);
  if (q) { const el = $("#q"); el.focus(); el.setSelectionRange(pos, pos); }
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
  if (!el) return;
  const a = el.dataset.act, v = el.dataset.v;
  if (a === "lang") { S.lang = v; savePref("lang", v); render(); }
  else if (a === "tab") {
    S.tab = v; S.detail = null; if (v === "settings") S.form = null;
    if (v === "log") S.logText = null;
    render(); window.scrollTo(0, 0);
    if (v === "history") loadHistory();
    if (v === "log") loadLog();
  }
  else if (a === "logout") { await api("/api/logout", { body: {} }).catch(() => {}); S.session = null; stopPolling(); render(); }
  else if (a === "filter") { S.filter = v; savePref("filter", v); render(); }
  else if (a === "pick") { const id = +v; if (el.checked) S.picked.add(id); else S.picked.delete(id); render(); }
  else if (a === "pickall") { const l = visibleGuests(); if (el.checked) l.forEach(g => S.picked.add(g.id)); else l.forEach(g => S.picked.delete(g.id)); render(); }
  else if (a === "go") openStart(el.dataset.mode, el.dataset.t, el.dataset.reboot);
  else if (a === "mclose") closeModal();
  else if (a === "closerun") { S.run = null; render(); }
  else if (a === "detail") {
    S.detail = { id: v, events: [], loading: true }; render(); window.scrollTo(0, 0);
    const r = await api(`/api/events?run=${encodeURIComponent(v)}&from=0`).catch(() => null);
    if (S.detail && S.detail.id === v) { S.detail.events = r && r.ok ? r.data.events : []; S.detail.loading = false; render(); }
  }
  else if (a === "back") { S.detail = null; render(); }
  else if (a === "reloadhist") loadHistory();
  else if (a === "reloadlog") loadLog();
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
  if (k && S.form && el.tagName === "SELECT") { S.form[k] = el.value; render(); }
});
document.addEventListener("keydown", ev => {
  if (ev.key === "Escape") closeModal();
  else if ((ev.key === "Enter" || ev.key === " ") && ev.target.matches && ev.target.matches("tr[data-act]")) { ev.preventDefault(); ev.target.click(); }
});

async function boot() {
  const r = await api("/api/session").catch(() => null);
  if (r && r.ok) {
    S.session = r.data; S.busy = false; S.loginErr = "";
    render();
    loadInventory(); loadHistory();
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
