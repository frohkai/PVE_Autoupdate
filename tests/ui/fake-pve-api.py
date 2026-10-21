#!/usr/bin/env python3
# Stand-in for the Proxmox VE API (https://<node>:8006/api2/json) - only what the web UI uses for login.
# Test accounts (fixtures, not real passwords):
#   root@pam     test-root-pw    Sys.Audit + Sys.Modify
#   viewer@pve   test-view-pw    Sys.Audit only (read only)
#   nobody@pve   test-nobody-pw  no rights on the nodes
#   tfa@pve      test-tfa-pw     full rights, TOTP 123456 or recovery key 0a1b-2c3d-4e5f-6a7b
import http.server
import json
import ssl
import sys
import urllib.parse

FULL = {"nodes": {"Sys.Audit": 1, "Sys.Modify": 1, "Sys.PowerMgmt": 1}}
USERS = {
    "root@pam": ("test-root-pw", FULL, False),
    "viewer@pve": ("test-view-pw", {"nodes": {"Sys.Audit": 1}}, False),
    "nobody@pve": ("test-nobody-pw", {"nodes": {}}, False),
    "tfa@pve": ("test-tfa-pw", FULL, True),
}
CHALLENGE = "PVE:tfa@pve:!tfa!%7B%22totp%22%3Atrue%2C%22recovery%22%3A%22available%22%7D::sig"


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, data):
        b = json.dumps({"data": data}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/api2/json/access/domains":
            return self.reply(200, [{"realm": "pam", "type": "pam", "comment": "Linux PAM standard authentication"},
                                    {"realm": "pve", "type": "pve", "comment": "Proxmox VE authentication server"}])
        self.reply(401, None)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        f = dict(urllib.parse.parse_qsl(self.rfile.read(n).decode()))
        if self.path != "/api2/json/access/ticket":
            return self.reply(501, None)
        user = f.get("username", "")
        if f.get("tfa-challenge"):
            ok = f["tfa-challenge"] == CHALLENGE and f.get("password") in ("totp:123456", "recovery:0a1b-2c3d-4e5f-6a7b")
            if user == "tfa@pve" and ok:
                return self.reply(200, {"username": user, "ticket": "PVE:tfa@pve:full", "cap": FULL})
            return self.reply(401, None)
        u = USERS.get(user)
        if not u or f.get("password") != u[0]:
            return self.reply(401, None)
        if u[2]:
            return self.reply(200, {"username": user, "ticket": CHALLENGE, "NeedTFA": 1})
        self.reply(200, {"username": user, "ticket": "PVE:%s:ticket" % user, "CSRFPreventionToken": "x", "cap": u[1]})


port, cert, key = int(sys.argv[1]), sys.argv[2], sys.argv[3]
srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(cert, key)
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
