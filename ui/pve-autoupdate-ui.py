#!/usr/bin/env python3
# Copyright (c) 2026 Kai Frohwerk
# License: MIT | https://github.com/frohkai/PVE_Autoupdate
#
# pve-autoupdate web UI - runs in its own LXC container.
#
#   login    Proxmox VE API (/access/ticket) - same users, realms and 2FA as the Proxmox UI.
#            Viewing needs Sys.Audit on the nodes, starting updates Sys.Modify.
#   actions  SSH to the node with a key that may only run "pve-autoupdate remote"
#            (forced command, set up by "pve-autoupdate pair").
#
# Python standard library only - nothing to pip install.

import hashlib
import hmac
import http.client
import http.server
import json
import os
import re
import secrets
import socketserver
import ssl
import subprocess
import sys
import threading
import time
import urllib.parse

VERSION = "0.1.0"
CONF_PATH = os.environ.get("PVEAU_UI_CONF", "/etc/pve-autoupdate-ui/config.json")
STATIC = os.environ.get("PVEAU_UI_STATIC", os.path.join(os.path.dirname(os.path.abspath(__file__)), "static"))

DEFAULTS = {
    "listen": "0.0.0.0",
    "port": 8443,
    "tls": True,
    "cert": "/etc/pve-autoupdate-ui/ui.crt",
    "key": "/etc/pve-autoupdate-ui/ui.key",
    "node": "",                  # node name, shown in the header
    "host": "",                  # node IP for API + SSH
    "api_port": 8006,
    "api_fingerprint": "",       # SHA256 of the node's API certificate (set by the installer)
    "ssh_key": "/etc/pve-autoupdate-ui/id_ed25519",
    "known_hosts": "/etc/pve-autoupdate-ui/known_hosts",
    "ssh_cmd": "ssh",
    "session_hours": 8,          # absolute session lifetime
    "idle_minutes": 120,         # logout after this much inactivity
}

ARG_RE = re.compile(r"^[A-Za-z0-9._,:=-]+$")
TARGET_RE = re.compile(r"^([0-9]{1,9}|node:[A-Za-z0-9._-]{1,63})$")
RUN_RE = re.compile(r"^[0-9]{8}-[0-9]{6}$")
RECOVERY_RE = re.compile(r"^[0-9a-fA-F]{4}(-[0-9a-fA-F]{4}){3}$")   # Proxmox recovery keys look like 0a1b-2c3d-4e5f-6a7b


def load_conf():
    c = dict(DEFAULTS)
    try:
        with open(CONF_PATH, encoding="utf-8") as f:
            c.update(json.load(f))
    except FileNotFoundError:
        pass
    return c


CONF = load_conf()
CONF_LOCK = threading.Lock()


def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), msg, file=sys.stderr, flush=True)


# --------------------------------------------------------------------------- Proxmox API (login)
class ApiError(Exception):
    pass


def pve_call(method, path, form=None):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE          # self-signed - checked by fingerprint below
    conn = http.client.HTTPSConnection(CONF["host"], int(CONF["api_port"]), context=ctx, timeout=20)
    try:
        conn.connect()
        pin = CONF.get("api_fingerprint", "").replace(":", "").lower()
        if pin:
            got = hashlib.sha256(conn.sock.getpeercert(True)).hexdigest()
            if not hmac.compare_digest(got, pin) and not repin(got):
                raise ApiError("certificate of %s does not match the pinned fingerprint" % CONF["host"])
        body = urllib.parse.urlencode(form) if form is not None else None
        hdr = {"Content-Type": "application/x-www-form-urlencoded"} if body else {}
        conn.request(method, "/api2/json" + path, body, hdr)
        r = conn.getresponse()
        raw = r.read()
    except (OSError, http.client.HTTPException) as e:
        raise ApiError("Proxmox API not reachable: %s" % e)
    finally:
        conn.close()
    try:
        data = json.loads(raw or b"{}").get("data")
    except ValueError:
        data = None
    return r.status, data


def repin(seen):
    """The API certificate changed (renewal, ACME). Ask the node over SSH - whose host key
    is pinned - which certificate pveproxy really serves; take it over only if it matches."""
    try:
        res = remote_json(["api-fingerprint"], timeout=20)
    except (ApiError, ValueError):
        return False
    real = str(res.get("sha256", "")).replace(":", "").lower() if isinstance(res, dict) else ""
    if not real or not hmac.compare_digest(real, seen):
        log("API certificate of %s does not match what the node reports - refused" % CONF["host"])
        return False
    with CONF_LOCK:
        CONF["api_fingerprint"] = seen
        try:
            with open(CONF_PATH, encoding="utf-8") as f:
                saved = json.load(f)
            saved["api_fingerprint"] = seen
            tmp = CONF_PATH + ".tmp"
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(json.dumps(saved, indent=2) + "\n")
            os.replace(tmp, CONF_PATH)
        except (OSError, ValueError) as e:
            log("could not save the new API fingerprint: %s" % e)
    log("API certificate of %s changed - new fingerprint taken over (confirmed by the node)" % CONF["host"])
    return True


def caps_of(data):
    nodes = (data or {}).get("cap", {}).get("nodes", {}) or {}
    return bool(nodes.get("Sys.Audit")), bool(nodes.get("Sys.Modify"))


# --------------------------------------------------------------------------- node commands (SSH)
def remote(args, stdin=None, timeout=60):
    for a in args:
        if not ARG_RE.match(a):
            raise ValueError("bad argument")
    cmd = [CONF["ssh_cmd"], "-i", CONF["ssh_key"], "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
           "-o", "UserKnownHostsFile=" + CONF["known_hosts"], "-o", "ConnectTimeout=10", "-o", "LogLevel=ERROR",
           "root@" + CONF["host"], " ".join(args)]
    try:
        p = subprocess.run(cmd, input=stdin.encode() if stdin else None, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")


def remote_json(args, stdin=None, timeout=60):
    rc, out, err = remote(args, stdin, timeout)
    try:
        return json.loads(out)
    except ValueError:
        raise ApiError((err or out or "no answer from %s" % CONF["host"]).strip().splitlines()[-1][:300])


# --------------------------------------------------------------------------- sessions
SESSIONS = {}          # token -> dict(user, write, csrf, created, seen)
PENDING_TFA = {}       # id -> dict(username, ticket, exp)
FAILS = {}             # ip -> [timestamps]
LOCK = threading.Lock()


def new_session(user, write):
    tok = secrets.token_urlsafe(32)
    now = time.time()
    with LOCK:
        SESSIONS[tok] = {"user": user, "write": write, "csrf": secrets.token_urlsafe(24), "created": now, "seen": now}
    return tok


def get_session(tok):
    if not tok:
        return None
    now = time.time()
    with LOCK:
        s = SESSIONS.get(tok)
        if not s:
            return None
        if now - s["created"] > CONF["session_hours"] * 3600 or now - s["seen"] > CONF["idle_minutes"] * 60:
            del SESSIONS[tok]
            return None
        s["seen"] = now
        return s


def throttled(ip):
    now = time.time()
    with LOCK:
        recent = [t for t in FAILS.get(ip, []) if now - t < 600]
        FAILS[ip] = recent
        return len(recent) >= 5


def failed(ip):
    with LOCK:
        FAILS.setdefault(ip, []).append(time.time())


def finish_login(ip, data, username):
    audit, write = caps_of(data)
    if not audit:
        log("login refused for %s from %s: no Sys.Audit" % (username, ip))
        return 403, {"error": "no_permission"}, None
    log("login %s from %s (%s)" % (username, ip, "write" if write else "read only"))
    return 200, {"ok": True}, new_session(username, write)


def do_login(ip, body):
    if throttled(ip):
        return 429, {"error": "too_many_attempts"}, None
    code = str(body.get("code", "")).strip()
    pend = str(body.get("pending", ""))
    if pend:                                           # second step: 2FA code
        with LOCK:
            p = PENDING_TFA.pop(pend, None)
        if not p or p["exp"] < time.time():
            return 401, {"error": "expired"}, None
        if not re.match(r"^[0-9A-Za-z-]{4,64}$", code):
            failed(ip)
            return 401, {"error": "bad_code"}, None
        kind = "recovery" if RECOVERY_RE.match(code) else "totp"
        st, data = pve_call("POST", "/access/ticket", {"username": p["username"], "tfa-challenge": p["ticket"],
                                                         "password": "%s:%s" % (kind, code)})
        if st != 200 or not data or not data.get("ticket"):
            failed(ip)
            log("2FA failed for %s from %s" % (p["username"], ip))
            return 401, {"error": "bad_code"}, None
        return finish_login(ip, data, p["username"])

    user = str(body.get("username", "")).strip()
    realm = str(body.get("realm", "pam")).strip() or "pam"
    pw = str(body.get("password", ""))
    if not user or not pw or len(user) > 128 or len(pw) > 512 or not re.match(r"^[A-Za-z0-9._@!-]+$", user + realm):
        return 400, {"error": "missing"}, None
    username = user if "@" in user else "%s@%s" % (user, realm)
    st, data = pve_call("POST", "/access/ticket", {"username": username, "password": pw})
    if st != 200 or not data or not data.get("ticket"):
        failed(ip)
        log("login failed for %s from %s" % (username, ip))
        return 401, {"error": "bad_login"}, None
    if data.get("NeedTFA"):
        pid = secrets.token_urlsafe(16)
        with LOCK:
            PENDING_TFA[pid] = {"username": username, "ticket": data["ticket"], "exp": time.time() + 300}
        return 200, {"tfa": True, "pending": pid}, None
    return finish_login(ip, data, username)


# --------------------------------------------------------------------------- HTTP
STATIC_TYPES = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
                ".js": "text/javascript; charset=utf-8", ".svg": "image/svg+xml", ".png": "image/png",
                ".ico": "image/x-icon"}


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "pve-autoupdate-ui"
    sys_version = ""

    def log_message(self, fmt, *args):
        pass

    # ---- helpers
    def send(self, code, body, ctype="application/json; charset=utf-8", headers=None):
        if isinstance(body, (dict, list)):
            body = json.dumps(body, ensure_ascii=False)
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy",
                         "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; "
                         "connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def cookie(self):
        for part in self.headers.get("Cookie", "").split(";"):
            k, _, v = part.strip().partition("=")
            if k == "pveau_session":
                return v
        return ""

    def set_cookie(self, tok, max_age):
        sec = "; Secure" if CONF["tls"] else ""
        return {"Set-Cookie": "pveau_session=%s; Path=/; HttpOnly; SameSite=Strict%s; Max-Age=%d" % (tok, sec, max_age)}

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 65536:
            raise ValueError("too large")
        if n and "application/json" not in self.headers.get("Content-Type", ""):
            raise ValueError("json only")
        raw = self.rfile.read(n) if n else b"{}"
        d = json.loads(raw or b"{}")
        if not isinstance(d, dict):
            raise ValueError("object expected")
        return d

    def session(self, write=False):
        s = get_session(self.cookie())
        if not s:
            self.send(401, {"error": "login"})
            return None
        if self.command == "POST" and not hmac.compare_digest(self.headers.get("X-PVEAU-CSRF", ""), s["csrf"]):
            self.send(403, {"error": "csrf"})
            return None
        if write and not s["write"]:
            self.send(403, {"error": "read_only"})
            return None
        return s

    # ---- routes
    def do_GET(self):
        u = urllib.parse.urlsplit(self.path)
        q = dict(urllib.parse.parse_qsl(u.query))
        try:
            if u.path == "/api/session":
                s = get_session(self.cookie())
                if not s:
                    return self.send(401, {"error": "login", "node": CONF["node"], "version": VERSION})
                return self.send(200, {"user": s["user"], "write": s["write"], "csrf": s["csrf"],
                                       "node": CONF["node"], "version": VERSION})
            if u.path == "/api/realms":
                try:
                    st, data = pve_call("GET", "/access/domains")
                    realms = [{"realm": r.get("realm"), "comment": r.get("comment", "")} for r in (data or [])]
                except ApiError:
                    realms = []
                return self.send(200, realms or [{"realm": "pam", "comment": "Linux PAM"}, {"realm": "pve", "comment": "Proxmox VE"}])
            if u.path.startswith("/api/"):
                if not self.session():
                    return
                if u.path == "/api/inventory":
                    return self.send(200, remote_json(["inventory"], timeout=90))
                if u.path == "/api/history":
                    n = q.get("n", "30")
                    return self.send(200, remote_json(["history", n if n.isdigit() else "30"]))
                if u.path == "/api/events":
                    run, frm = q.get("run", ""), q.get("from", "0")
                    if not RUN_RE.match(run) or not frm.isdigit():
                        return self.send(400, {"error": "bad request"})
                    rc, out, err = remote(["events", run, frm])
                    evs = []
                    for line in out.splitlines():
                        try:
                            evs.append(json.loads(line))
                        except ValueError:
                            pass
                    return self.send(200, {"events": evs, "next": int(frm) + len(evs)})
                if u.path == "/api/log":
                    n = q.get("n", "300")
                    rc, out, err = remote(["log", n if n.isdigit() else "300"])
                    return self.send(200, out, "text/plain; charset=utf-8")
                return self.send(404, {"error": "not found"})
            return self.static(u.path)
        except ApiError as e:
            return self.send(502, {"error": "node", "detail": str(e)})

    def do_POST(self):
        u = urllib.parse.urlsplit(self.path)
        ip = self.client_address[0]
        try:
            body = self.body()
        except ValueError:
            return self.send(400, {"error": "bad request"})
        try:
            if u.path == "/api/login":
                code, res, tok = do_login(ip, body)
                hdr = self.set_cookie(tok, int(CONF["session_hours"] * 3600)) if tok else None
                return self.send(code, res, headers=hdr)
            if u.path == "/api/logout":
                tok = self.cookie()
                with LOCK:
                    SESSIONS.pop(tok, None)
                return self.send(200, {"ok": True}, headers=self.set_cookie("", 0))
            if u.path == "/api/start":
                s = self.session(write=True)
                if not s:
                    return
                args = ["start"]
                if body.get("mode") == "check":
                    args.append("--dry-run")
                targets = body.get("targets") or []
                if not isinstance(targets, list) or not all(isinstance(t, (str, int)) and TARGET_RE.match(str(t)) for t in targets):
                    return self.send(400, {"error": "bad targets"})
                if targets:
                    args.append("--only=" + ",".join(str(t) for t in targets))
                if body.get("reboot") in ("yes", "no"):
                    args.append("--reboot" if body["reboot"] == "yes" else "--no-reboot")
                if body.get("ignore_window"):
                    args.append("--ignore-window")
                res = remote_json(args)
                if res.get("ok"):
                    log("%s started run %s: %s" % (s["user"], res.get("run"), " ".join(args[1:]) or "full run"))
                return self.send(200 if res.get("ok") else 409, res)
            if u.path == "/api/config":
                s = self.session(write=True)
                if not s:
                    return
                res = remote_json(["config", "set"], stdin=json.dumps(body))
                if res.get("ok"):
                    log("%s changed settings: %s" % (s["user"], " ".join(res.get("changed", []))))
                return self.send(200 if res.get("ok") else 400, res)
            if u.path == "/api/test-mail":
                s = self.session(write=True)
                if not s:
                    return
                rc, out, err = remote(["test-mail"], timeout=90)
                return self.send(200, {"ok": rc == 0, "output": (out + err)[-2000:]})
            return self.send(404, {"error": "not found"})
        except ApiError as e:
            return self.send(502, {"error": "node", "detail": str(e)})

    def static(self, path):
        if path == "/":
            path = "/index.html"
        name = path.lstrip("/")
        if "/" in name or name.startswith(".") or name not in os.listdir(STATIC):
            return self.send(404, "not found", "text/plain")
        ext = os.path.splitext(name)[1]
        with open(os.path.join(STATIC, name), "rb") as f:
            return self.send(200, f.read(), STATIC_TYPES.get(ext, "application/octet-stream"))


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    if not CONF["host"]:
        sys.exit("no node configured in %s" % CONF_PATH)
    srv = Server((CONF["listen"], int(CONF["port"])), Handler)
    if CONF["tls"]:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        ctx.load_cert_chain(CONF["cert"], CONF["key"])
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    log("pve-autoupdate-ui %s listening on %s:%s (node %s @ %s)" % (VERSION, CONF["listen"], CONF["port"], CONF["node"], CONF["host"]))
    srv.serve_forever()


if __name__ == "__main__":
    main()
