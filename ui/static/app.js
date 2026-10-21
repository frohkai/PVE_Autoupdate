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
    search: "Search name or ID ...", all: "All", cts: "Containers", vms: "VMs", auto_only: "Automatic",
    selected: "selected", auto: "Automatic", auto_tip: "updated by the schedule", manual_tip: "only when you start it here",
    id: "ID", name: "Name", type: "Type", node: "Node", status: "Status", actions: "",
    st_running: "running", st_stopped: "stopped", template: "template",
    no_guests: "No containers or VMs found.", no_match: "Nothing matches the filter.",
    run_check: "Check running", run_update: "Update running", run_done: "Finished", run_aborted: "Aborted",
    run_rebooting: "Nodes are rebooting - the post check follows after boot", run_window: "Nothing done - outside the update window", close: "Close", waiting: "waiting for the first result ...",
    cancel: "Cancel", start: "Start",
    m_check_t: "Check for updates", m_check_p: "Only looks - nothing is installed or changed.",
    m_update_t: "Install updates now", m_update_p: "A snapshot is taken before every update. If the health check fails afterwards, the guest is rolled back automatically.",
    m_all: "everything that is set to automatic", allow_reboot: "Reboot if an update needs it",
    allow_reboot_node: "Reboot the node if needed (cluster: one after another, quorum is checked; guests on it are briefly offline)",
    outside_window: "It is outside the update window ({w}).", force_window: "Run anyway",
    started: "Started", already_running: "An update is already running.", failed_start: "Could not start",
    h_when: "Started", h_kind: "Kind", h_target: "Targets", h_result: "Result", h_by: "By",
    k_update: "Update", k_check: "Check", by_ui: "web UI", by_cli: "schedule / console", all_selected: "selection",
    no_history: "No runs yet.", back: "Back", results: "Results", events: "Log of this run", refresh: "Refresh",
    log_title: "Log on the node", pkgs: "{n} pkg", post: "Post check",
    s_running: "running", s_ok: "OK", s_fail: "errors", s_aborted: "aborted", s_rebooting: "rebooting", s_window: "outside the time window", s_problems: "with problems",
    ago_s: "just now", ago_m: "{n} min ago", ago_h: "{n} h ago", ago_d: "{n} d ago", in_x: "in {x}",
    up_to_date: "up to date", reboot_needed: "reboot needed",
    os_windows: "Windows", os_linux: "Linux",
  },
  de: {
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
    search: "Name oder ID suchen ...", all: "Alle", cts: "Container", vms: "VMs", auto_only: "Automatisch",
    selected: "ausgewählt", auto: "Automatisch", auto_tip: "wird nach Zeitplan aktualisiert", manual_tip: "nur wenn du es hier startest",
    id: "ID", name: "Name", type: "Typ", node: "Node", status: "Status", actions: "",
    st_running: "läuft", st_stopped: "gestoppt", template: "Vorlage",
    no_guests: "Keine Container oder VMs gefunden.", no_match: "Nichts passt zum Filter.",
    run_check: "Prüfung läuft", run_update: "Update läuft", run_done: "Fertig", run_aborted: "Abgebrochen",
    run_rebooting: "Nodes starten neu - die Nachkontrolle folgt nach dem Start", run_window: "Nichts getan - außerhalb des Update-Zeitfensters", close: "Schließen", waiting: "warte auf das erste Ergebnis ...",
    cancel: "Abbrechen", start: "Starten",
    m_check_t: "Nach Updates suchen", m_check_p: "Schaut nur nach - es wird nichts installiert oder verändert.",
    m_update_t: "Updates jetzt installieren", m_update_p: "Vor jedem Update wird ein Snapshot angelegt. Schlägt der Health-Check danach fehl, wird der Gast automatisch zurückgesetzt.",
    m_all: "alles, was auf automatisch steht", allow_reboot: "Neu starten, wenn ein Update es braucht",
    allow_reboot_node: "Node bei Bedarf neu starten (Cluster: nacheinander, Quorum wird geprüft; Gäste darauf sind kurz offline)",
    outside_window: "Es ist außerhalb des Update-Zeitfensters ({w}).", force_window: "Trotzdem ausführen",
    started: "Gestartet", already_running: "Es läuft bereits ein Update.", failed_start: "Konnte nicht starten",
    h_when: "Gestartet", h_kind: "Art", h_target: "Ziele", h_result: "Ergebnis", h_by: "Von",
    k_update: "Update", k_check: "Prüfung", by_ui: "Weboberfläche", by_cli: "Zeitplan / Konsole", all_selected: "Auswahl",
    no_history: "Noch keine Läufe.", back: "Zurück", results: "Ergebnisse", events: "Protokoll dieses Laufs", refresh: "Aktualisieren",
    log_title: "Protokoll auf dem Node", pkgs: "{n} Pak.", post: "Nachkontrolle",
    s_running: "läuft", s_ok: "OK", s_fail: "Fehler", s_aborted: "abgebrochen", s_rebooting: "Neustart", s_window: "außerhalb Zeitfenster", s_problems: "mit Problemen",
    ago_s: "gerade eben", ago_m: "vor {n} Min.", ago_h: "vor {n} Std.", ago_d: "vor {n} Tg.", in_x: "in {x}",
    up_to_date: "aktuell", reboot_needed: "Neustart nötig",
    os_windows: "Windows", os_linux: "Linux",
  },
};

// ------------------------------------------------------------------ state
const S = {
  lang: loadPref("lang") || ((navigator.language || "en").slice(0, 2) === "de" ? "de" : "en"),
  session: null, inv: null, invErr: "", history: null, tab: "overview",
  filter: loadPref("filter") || "all", q: "", picked: new Set(),
  run: null,            // {id, from, events, done, mode}
  detail: null,         // {id, events}
  logText: "", loginErr: "", tfa: null, busy: false,
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
function badge(st, label) { return `<span class="badge b-${esc(st)}">${esc(label || st)}</span>`; }
function runStatusBadge(st, problems) {   // a run that ended "ok" can still have rollbacks or warnings
  if (st === "ok" && +problems > 0) return badge("WARN", t("s_problems"));
  const map = { ok: ["OK", "s_ok"], fail: ["FAIL", "s_fail"], running: ["RUN", "s_running"], aborted: ["SKIP", "s_aborted"], rebooting: ["TEST", "s_rebooting"], window: ["SKIP", "s_window"] };
  const m = map[st] || ["SKIP", st];
  return badge(m[0], t(m[1]));
}
function osTag(g) {
  const os = (g.os || "").toLowerCase();
  if (os.startsWith("w")) return `<span class="tag win">${t("os_windows")}</span>`;
  if (!os) return "";
  if (os === "l26" || os === "l24") return `<span class="tag">${t("os_linux")}</span>`;
  return `<span class="tag">${esc(os)}</span>`;
}
function resultCell(r, slot) {
  if (!r || !r[slot]) return `<span class="faint">${t("none_yet")}</span>`;
  const x = r[slot];
  let sum = x.summary || "";
  if (x.reboot) sum += " · " + t("reboot_needed");
  return `<div title="${esc(fmt(x.ts) + " - " + sum)}">${badge(x.status)}<span>${esc(sum)}</span><small>${esc(ago(x.ts))}</small></div>`;
}
function lastOf(kind, id) { return (S.inv && S.inv.last && S.inv.last[kind + ":" + id]) || null; }
const canWrite = () => S.session && S.session.write;
const isRunning = () => (S.inv && S.inv.running) || (S.run && !S.run.done);

// ------------------------------------------------------------------ login
function renderLogin() {
  const realms = S.realms || [{ realm: "pam", comment: "Linux PAM" }, { realm: "pve", comment: "Proxmox VE" }];
  const err = S.loginErr ? `<div class="err">${esc(S.loginErr)}</div>` : "";
  let form;
  if (S.tfa) {
    form = `<form id="f-tfa">${err}
      <label class="field"><span>${t("code")}</span><input id="code" autocomplete="one-time-code" inputmode="numeric" required autofocus></label>
      <p class="muted">${t("code_hint")}</p>
      <button class="btn primary" ${S.busy ? "disabled" : ""}>${S.busy ? '<span class="spin"></span>' : ""}${t("verify")}</button></form>`;
  } else {
    form = `<form id="f-login">${err}
      <label class="field"><span>${t("user")}</span><input id="user" autocomplete="username" value="root" required></label>
      <label class="field"><span>${t("password")}</span><input id="pw" type="password" autocomplete="current-password" required autofocus></label>
      <label class="field"><span>${t("realm")}</span><select id="realm">${realms.map(r =>
        `<option value="${esc(r.realm)}">${esc(r.comment || r.realm)} (${esc(r.realm)})</option>`).join("")}</select></label>
      <button class="btn primary" ${S.busy ? "disabled" : ""}>${S.busy ? '<span class="spin"></span>' : ""}${t("sign_in")}</button></form>`;
  }
  return `<div class="login"><div class="card">
    <div class="brand"><img src="logo.svg" alt=""><div><div class="kicker">&gt;_ pve-autoupdate</div><h1>${t("login_title")}</h1>
      <div class="muted">${t("login_sub")}${S.node ? " · " + esc(S.node) : ""}</div></div></div>
    ${form}
    <div class="foot"><span>by ${esc(AUTHOR)} · <a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a></span>${langSwitch()}</div>
  </div></div>`;
}
function langSwitch() {
  return `<div class="lang"><button data-act="lang" data-v="en" class="${S.lang === "en" ? "on" : ""}">EN</button><button data-act="lang" data-v="de" class="${S.lang === "de" ? "on" : ""}">DE</button></div>`;
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
  const tab = (k) => `<button class="tab ${S.tab === k ? "on" : ""}" data-act="tab" data-v="${k}">${t(k)}</button>`;
  let body = "";
  if (S.tab === "overview") body = renderOverview();
  else if (S.tab === "history") body = S.detail ? renderDetail() : renderHistory();
  else body = renderLog();
  return `<header class="top"><div class="in">
      <div class="logo"><img src="logo.svg" alt=""><div><b><i>&gt;_</i> pve-autoupdate</b><small>by ${esc(AUTHOR)}</small></div></div>
      <nav class="tabs">${tab("overview")}${tab("history")}${tab("log")}</nav>
      <div class="right"><span class="chip"><b>${esc(where)}</b></span>
        <span class="chip user">${esc(S.session.user)}${canWrite() ? "" : " · " + t("read_only")}</span>
        ${langSwitch()}<button class="btn sm ghost" data-act="logout">${t("logout")}</button></div>
    </div></header>
    <main>${S.invErr ? `<div class="banner err">${t("node_down")}: ${esc(S.invErr)}</div>` : ""}
      ${canWrite() ? "" : `<div class="banner ro">${t("ro_banner")}</div>`}${body}</main>
    <footer><span>pve-autoupdate ${esc(inv ? inv.version : "")} · UI ${esc(S.session.version)}</span>
      <span>by ${esc(AUTHOR)} · <a href="${WEBSITE}" target="_blank" rel="noopener">kaimazon.de</a></span>
      <a href="${REPO_URL}" target="_blank" rel="noopener">GitHub</a>
      ${hasDonate() ? `<a href="${DONATE_URL}" target="_blank" rel="noopener"><span class="heart">♥</span> Liberapay</a>` : ""}</footer>`;
}

// ------------------------------------------------------------------ overview
function renderOverview() {
  const inv = S.inv;
  if (!inv) return `<div class="empty"><span class="spin"></span></div>`;
  const c = inv.config || {};
  const nr = nextRunTxt(inv.next_run);
  const win = c.UPDATE_WINDOW ? `${c.UPDATE_WINDOW.replace("-", " – ")} · ${inv.in_window ? t("window_open") : t("window_closed")}` : t("no_window");
  const last = (S.history && S.history[0]) || null;
  let state = `<div class="v">${t("idle")}</div><div class="s">${esc(win)}</div>`;
  if (isRunning()) state = `<div class="v"><span class="spin"></span> ${t("running")}</div><div class="s">${esc(win)}</div>`;
  else if (inv.reboot_pending) state = `<div class="v">${t("reboot_pending")}</div><div class="s">${esc(win)}</div>`;
  const lastHtml = last
    ? `<div class="v">${runStatusBadge(last.status, last.problems)} ${esc(last.mode === "dryrun" ? t("k_check") : t("k_update"))}</div><div class="s" title="${esc(last.subject || "")}">${esc(ago(last.start))} · ${esc(last.subject || "")}</div>`
    : `<div class="v">${t("never")}</div><div class="s"></div>`;

  const w = canWrite(), dis = isRunning() ? "disabled" : "";
  const stats = `<div class="stats">
    <div class="stat"><div class="k">${t("schedule")}</div><div class="v" title="${esc(c.SCHEDULE || "")}">${esc(inv.schedule_text || "-")}</div><div class="s">${esc(c.SCHEDULE || "")}</div></div>
    <div class="stat"><div class="k">${t("next_run")}</div><div class="v">${esc(nr.v)}</div><div class="s">${esc(nr.s)}</div></div>
    <div class="stat"><div class="k">${t("last_run")}</div>${lastHtml}</div>
    <div class="stat"><div class="k">${t("state")}</div>${state}</div></div>`;

  const nodes = inv.nodes.map(n => {
    const l = lastOf("NODE", n.name);
    return `<div class="node"><div class="hd"><span class="dot ${n.online ? "on" : "off"}"></span><b>${esc(n.name)}</b>
        ${n.name === inv.self ? '<span class="tag">UI</span>' : ""}<span class="ip">${esc(n.ip)}</span></div>
      <div class="ln"><span class="muted">${t("last_check")}:</span>${l && l.check ? badge(l.check.status) + `<span>${esc(l.check.summary)}${l.check.reboot ? " · " + t("reboot_needed") : ""}</span>` : `<span class="faint">${t("none_yet")}</span>`}</div>
      <div class="ln"><span class="muted">${t("last_update")}:</span>${l && l.update ? badge(l.update.status) + `<span>${esc(l.update.summary)} · ${esc(ago(l.update.ts))}</span>` : `<span class="faint">${t("none_yet")}</span>`}</div>
      ${w ? `<div class="bt"><button class="btn sm" data-act="go" data-mode="check" data-t="node:${esc(n.name)}" ${dis}>${t("check")}</button>
        <button class="btn sm" data-act="go" data-mode="update" data-t="node:${esc(n.name)}" ${dis}>${t("update")}</button>
        <button class="btn sm danger" data-act="go" data-mode="update" data-reboot="yes" data-t="node:${esc(n.name)}" ${dis}>${t("update_reboot")}</button></div>` : ""}
    </div>`;
  }).join("");

  return `${stats}${renderRun()}
    <h2>${t("nodes")} <span class="count">${inv.nodes.length}</span>
      ${w ? `<span class="actions"><button class="btn sm" data-act="go" data-mode="check" ${dis}>${t("check_all")}</button>
      <button class="btn sm primary" data-act="go" data-mode="update" ${dis}>${t("update_all")}</button></span>` : ""}</h2>
    <div class="nodes">${nodes}</div>
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
  const seg = (k, l) => `<button data-act="filter" data-v="${k}" class="${S.filter === k ? "on" : ""}">${l}</button>`;
  const picked = [...S.picked].filter(id => all.some(g => g.id === id));
  const allPicked = list.length > 0 && list.every(g => S.picked.has(g.id));
  const rows = list.map(g => {
    const kind = g.type === "qemu" ? "VM" : "LXC";
    const l = lastOf(kind, g.id);
    return `<tr class="${S.picked.has(g.id) ? "picked" : ""}">
      ${w ? `<td><input type="checkbox" data-act="pick" data-v="${g.id}" ${S.picked.has(g.id) ? "checked" : ""}></td>` : ""}
      <td class="id">${g.id}</td>
      <td class="nm"><b>${esc(g.name)}</b> ${osTag(g)}</td>
      <td class="hide-s"><span class="tag">${g.type === "qemu" ? "VM" : "CT"}</span></td>
      <td class="hide-m">${esc(g.node)}</td>
      <td class="hide-s nw"><span class="dot ${g.status === "running" ? "on" : ""}"></span>${esc(g.status === "running" ? t("st_running") : t("st_stopped"))}</td>
      <td class="hide-s" title="${esc(g.selected ? t("auto_tip") : t("manual_tip"))}">${g.selected ? '<span class="auto">✓</span>' : '<span class="faint">–</span>'}</td>
      <td class="res hide-m">${resultCell(l, "check")}</td>
      <td class="res">${resultCell(l, "update")}</td>
      ${w ? `<td class="act"><button class="btn sm" data-act="go" data-mode="check" data-t="${g.id}" ${dis}>${t("check")}</button><button class="btn sm" data-act="go" data-mode="update" data-t="${g.id}" ${dis}>${t("update")}</button></td>` : ""}
    </tr>`;
  }).join("");
  return `<h2>${t("guests")} <span class="count">${all.length}</span></h2>
    <div class="toolbar"><input type="search" id="q" placeholder="${esc(t("search"))}" value="${esc(S.q)}">
      <div class="seg">${seg("all", t("all"))}${seg("lxc", t("cts"))}${seg("qemu", t("vms"))}${seg("auto", t("auto_only"))}</div>
      ${w && picked.length ? `<div class="sel">${picked.length} ${t("selected")}
        <button class="btn sm" data-act="go" data-mode="check" data-t="picked" ${dis}>${t("check")}</button>
        <button class="btn sm primary" data-act="go" data-mode="update" data-t="picked" ${dis}>${t("update")}</button></div>` : ""}</div>
    <div class="tblwrap"><table class="tbl"><thead><tr>
      ${w ? `<th><input type="checkbox" data-act="pickall" ${allPicked ? "checked" : ""}></th>` : ""}
      <th>${t("id")}</th><th>${t("name")}</th><th class="hide-s">${t("type")}</th><th class="hide-m">${t("node")}</th>
      <th class="hide-s">${t("status")}</th><th class="hide-s">${t("auto")}</th><th class="hide-m">${t("last_check")}</th><th>${t("last_update")}</th>${w ? "<th></th>" : ""}
    </tr></thead><tbody>${rows || `<tr><td colspan="10" class="empty">${all.length ? t("no_match") : t("no_guests")}</td></tr>`}</tbody></table></div>`;
}

// ------------------------------------------------------------------ live run panel
function resultRows(events) {
  return events.filter(e => e.ev === "result").map(e => {
    const who = e.kind === "NODE" ? "Node " + e.id : `${e.kind} ${e.id} ${e.name ? "(" + e.name + ")" : ""}`;
    return `<div class="r">${badge(e.status)}<span class="who">${esc(who)}</span><span class="sum" title="${esc(e.summary)}">${esc(e.summary)}${e.reboot === "yes" ? " · " + t("reboot_needed") : ""}</span></div>`;
  }).join("");
}
function logLines(events, max) {
  const l = events.filter(e => e.ev === "log").slice(-max);
  return l.map(e => `<div><span class="t">${esc(new Date(e.ts * 1000).toLocaleTimeString(S.lang === "de" ? "de-DE" : "en-GB"))}</span> ${esc(e.msg)}</div>`).join("");
}
function renderRun() {
  const r = S.run;
  if (!r) return "";
  const end = r.events.find(e => e.ev === "end");
  const rep = r.events.find(e => e.ev === "report");
  let title, cls = "";
  if (!r.done) title = `<span class="spin"></span><b>${r.mode === "dryrun" ? t("run_check") : t("run_update")}</b>`;
  else if (end && end.status === "rebooting") { title = `<b>${t("run_rebooting")}</b>`; cls = ""; }
  else if (end && end.status === "window") title = `<b>${t("run_window")}</b>`;
  else {
    title = `<b>${end ? t("run_done") : t("run_aborted")}</b>${rep ? ` <span class="muted">${esc(rep.subject)}</span>` : ""}`;
    cls = end && end.status === "ok" && !(rep && +rep.problems) ? "done-ok" : "done-bad";
  }
  const res = resultRows(r.events);
  return `<section class="run ${cls}"><div class="hd">${title}<span class="faint mono">${esc(r.id)}</span>
      ${r.done ? `<button class="btn sm ghost x" data-act="closerun">${t("close")}</button>` : ""}</div>
    <div class="body"><div class="results">${res || `<div class="r faint">${t("waiting")}</div>`}</div>
      <div class="lines" id="runlines">${logLines(r.events, 300)}</div></div></section>`;
}

// ------------------------------------------------------------------ history
function renderHistory() {
  const h = S.history;
  if (!h) return `<div class="empty"><span class="spin"></span></div>`;
  if (!h.length) return `<div class="empty">${t("no_history")}</div>`;
  const rows = h.map(r => `<tr data-act="detail" data-v="${esc(r.id)}">
      <td>${esc(fmt(r.start || runTs(r.id)))}<br><small class="faint">${esc(ago(r.start || runTs(r.id)))}</small></td>
      <td>${r.mode === "dryrun" ? t("k_check") : t("k_update")}</td>
      <td class="hide-s">${esc(r.only ? r.only.replace(/node:/g, "Node ") : t("all_selected"))}</td>
      <td>${runStatusBadge(r.status, r.problems)} <span class="muted">${esc(r.subject || "")}</span>${r.postcheck ? `<br><small class="faint">${t("post")}: Nodes ${esc(r.postcheck.nodes)}, ${esc(r.postcheck.guests)}</small>` : ""}</td>
      <td class="hide-m">${r.trigger === "ui" ? t("by_ui") : t("by_cli")}</td></tr>`).join("");
  return `<h2>${t("history")} <span class="count">${h.length}</span><span class="actions"><button class="btn sm" data-act="reloadhist">${t("refresh")}</button></span></h2>
    <div class="tblwrap"><table class="tbl click"><thead><tr><th>${t("h_when")}</th><th>${t("h_kind")}</th><th class="hide-s">${t("h_target")}</th><th>${t("h_result")}</th><th class="hide-m">${t("h_by")}</th></tr></thead>
    <tbody>${rows}</tbody></table></div>`;
}
function renderDetail() {
  const d = S.detail;
  const st = d.events.find(e => e.ev === "start") || {};
  const rep = d.events.find(e => e.ev === "report");
  const end = d.events.find(e => e.ev === "end");
  return `<div class="detail"><button class="btn sm back" data-act="back">← ${t("back")}</button>
    <h2>${st.mode === "dryrun" ? t("k_check") : t("k_update")} · ${esc(fmt(st.ts || runTs(d.id)))} ${end ? runStatusBadge(end.status, rep && rep.problems) : runStatusBadge("aborted")}</h2>
    <div class="kv"><span>${t("h_target")}: <b>${esc(st.only ? st.only.replace(/node:/g, "Node ") : t("all_selected"))}</b></span>
      <span>${t("h_by")}: <b>${st.trigger === "ui" ? t("by_ui") : t("by_cli")}</b></span><span>Nodes: <b>${esc(st.nodes || "")}</b></span>
      ${rep ? `<span>${esc(rep.subject)}</span>` : ""}</div>
    <h2>${t("results")}</h2><div class="run"><div class="results">${resultRows(d.events) || `<div class="r faint">-</div>`}</div></div>
    <h2>${t("events")}</h2><pre class="log">${d.events.filter(e => e.ev === "log").map(e => esc(new Date(e.ts * 1000).toLocaleTimeString() + "  " + e.msg)).join("\n")}</pre></div>`;
}
function renderLog() {
  return `<h2>${t("log_title")}<span class="actions"><button class="btn sm" data-act="reloadlog">${t("refresh")}</button></span></h2>
    <pre class="log" id="logpre">${esc(S.logText || "...")}</pre>`;
}

// ------------------------------------------------------------------ start dialog
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
  const m = $("#modal");
  m.innerHTML = `<div class="box" role="dialog" aria-modal="true">
    <h3>${mode === "check" ? t("m_check_t") : t("m_update_t")}</h3>
    <p>${mode === "check" ? t("m_check_p") : t("m_update_p")}</p>
    <ul>${targets.length ? names.map(n => `<li>${esc(n)}</li>`).join("") : `<li>${t("m_all")}</li>`}</ul>
    ${mode === "update" ? `<label class="opt"><input type="checkbox" id="o-reboot" ${defReboot ? "checked" : ""}><span>${hasNode ? t("allow_reboot_node") : t("allow_reboot")}</span></label>` : ""}
    ${outside ? `<div class="warnbox">${esc(t("outside_window", { w: c.UPDATE_WINDOW }))}</div><label class="opt"><input type="checkbox" id="o-force"><span>${t("force_window")}</span></label>` : ""}
    <div class="bt"><button class="btn" data-act="mclose">${t("cancel")}</button>
      <button class="btn primary" id="m-go" ${outside ? "disabled" : ""}>${t("start")}</button></div></div>`;
  m.classList.remove("hidden");
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
      else alert(r.data && r.data.error === "already running" ? t("already_running") : t("failed_start") + ": " + ((r.data && (r.data.detail || r.data.error)) || r.status));
    } catch (e) { closeModal(); }
  });
}
function closeModal() { const m = $("#modal"); m.classList.add("hidden"); m.innerHTML = ""; }

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
  try { const r = await api("/api/log?n=400"); S.logText = r.ok ? r.data : ""; } catch (e) { /* ignore */ }
  if (S.session) { render(); const p = $("#logpre"); if (p) p.scrollTop = p.scrollHeight; }
}
function stopPolling() { clearInterval(pollRun); clearInterval(pollInv); }

// ------------------------------------------------------------------ render + events
function render() {
  document.documentElement.lang = S.lang;
  const app = $("#app");
  const q = document.activeElement && document.activeElement.id === "q";
  const pos = q ? document.activeElement.selectionStart : 0;
  const y = window.scrollY;
  app.innerHTML = S.session ? renderApp() : renderLogin();
  window.scrollTo(0, y);
  if (q) { const el = $("#q"); el.focus(); el.setSelectionRange(pos, pos); }
  const fl = $("#f-login");
  if (fl) fl.addEventListener("submit", ev => { ev.preventDefault(); doLogin({ username: $("#user").value, password: $("#pw").value, realm: $("#realm").value }); });
  const ft = $("#f-tfa");
  if (ft) ft.addEventListener("submit", ev => { ev.preventDefault(); doLogin({ pending: S.tfa, code: $("#code").value.trim() }); });
  const qs = $("#q");
  if (qs) qs.addEventListener("input", () => { S.q = qs.value; render(); });
}

document.addEventListener("click", async ev => {
  const el = ev.target.closest("[data-act]");
  if (!el) return;
  const a = el.dataset.act, v = el.dataset.v;
  if (a === "lang") { S.lang = v; savePref("lang", v); render(); }
  else if (a === "tab") {
    S.tab = v; S.detail = null; render();
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
    S.detail = { id: v, events: [] }; render();
    const r = await api(`/api/events?run=${encodeURIComponent(v)}&from=0`);
    if (r.ok && S.detail && S.detail.id === v) { S.detail.events = r.data.events; render(); }
  }
  else if (a === "back") { S.detail = null; render(); }
  else if (a === "reloadhist") loadHistory();
  else if (a === "reloadlog") loadLog();
});
document.addEventListener("keydown", ev => { if (ev.key === "Escape") closeModal(); });

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
