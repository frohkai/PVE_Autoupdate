#!/usr/bin/env bash
# Web UI against a fake Proxmox API (tests/ui/fake-pve-api.py) and the mocked node from run-tests.sh.
# Meant for a throwaway container:
#
#   docker run --rm -v "$PWD:/src:ro" alpine sh -c "apk add -q bash python3 openssl curl && bash /src/tests/run-ui-tests.sh"
#
# UI_DEMO=1 skips the checks and keeps the UI running on http://<container>:8443 (plain http)
# for a look in the browser - add -e UI_DEMO=1 -p 127.0.0.1:8443:8443 to docker run.
# Test logins: root / test-root-pw (realm pam), more in tests/ui/fake-pve-api.py
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
export MOCK=/tmp/mock PVE_AUTOUPDATE_CLOCK=/tmp/clock
mkdir -p /usr/local/mockbin /usr/local/sbin && cp "$SRC"/tests/mocks/* /usr/local/mockbin/ && chmod +x /usr/local/mockbin/*
rm /usr/local/mockbin/systemd-run    # "start" then uses its setsid fallback: the run goes on in the background
install -m 755 "$SRC/tests/ui/ssh-shim" /usr/local/mockbin/ui-ssh
install -m 755 "$SRC/pve-autoupdate.sh" /usr/local/sbin/pve-autoupdate
export PATH="/usr/local/mockbin:$PATH"
AU=/usr/local/sbin/pve-autoupdate

# ---------------------------------------------------------------------------- the "cluster"
mkdir -p "$MOCK/beh" "$MOCK/state" /run/systemd/system /etc/systemd/system /boot /var/run /etc/pve-autoupdate
for n in pve1 pve2; do mkdir -p /etc/pve/nodes/$n/lxc /etc/pve/nodes/$n/qemu-server; done
: > "$MOCK/actions"
cat > "$MOCK/cluster.json" <<'EOF'
[{"type":"cluster","name":"homelab","nodes":2,"quorate":1},
 {"type":"node","name":"pve1","ip":"10.0.0.1","online":1,"local":1},
 {"type":"node","name":"pve2","ip":"10.0.0.2","online":1,"local":0}]
EOF
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":101,"type":"lxc","name":"web","node":"pve1","status":"running","template":0},
 {"vmid":102,"type":"lxc","name":"nextcloud","node":"pve1","status":"running","template":0},
 {"vmid":103,"type":"lxc","name":"pihole","node":"pve2","status":"running","template":0},
 {"vmid":104,"type":"lxc","name":"postgres","node":"pve2","status":"running","template":0},
 {"vmid":105,"type":"lxc","name":"old-test","node":"pve1","status":"stopped","template":0},
 {"vmid":200,"type":"qemu","name":"win11-office","node":"pve1","status":"running","template":0},
 {"vmid":201,"type":"qemu","name":"ubuntu-docker","node":"pve2","status":"running","template":0},
 {"vmid":900,"type":"lxc","name":"debian-tmpl","node":"pve1","status":"stopped","template":1}]
EOF
for c in pve1/lxc/101:debian pve1/lxc/102:debian pve2/lxc/103:alpine pve2/lxc/104:ubuntu pve1/lxc/105:debian \
         pve1/qemu-server/200:win11 pve2/qemu-server/201:l26; do
  echo "ostype: ${c#*:}" > "/etc/pve/nodes/${c%:*}.conf"
done
echo "PKGS=3" > "$MOCK/beh/101"
echo "PKGS=5 BREAK=1" > "$MOCK/beh/102"
echo "PKGS=1" > "$MOCK/beh/103"
echo "PKGS=2" > "$MOCK/beh/104"
echo "win11" > "$MOCK/beh/200.ostype"; echo "WUPD=2" > "$MOCK/beh/200.win"
echo "PKGS=4" > "$MOCK/beh/201"
echo "PKGS=6" > "$MOCK/beh/node-local"
echo "PKGS=2" > "$MOCK/beh/node-pve2"
cat > /etc/pve-autoupdate/config <<'EOF'
UI_LANG=en
TITLE=homelab
GUESTS='101 102 103 104 200 201'
UPDATE_HOSTS=1
REBOOT_HOSTS=0
SNAPSHOT=optional
NOTIFY=errors
MAIL_TO=admin@example.com
SETTLE=0
SCHEDULE='*-*-* 03:00:00'
UPDATE_WINDOW=02:00-06:00
EOF
echo "03:00" > /tmp/clock
# some history: a check of everything, then an update (102 gets rolled back)
$AU run --dry-run > /tmp/seed1.out 2>&1; /bin/sleep 1
$AU run > /tmp/seed2.out 2>&1; /bin/sleep 1

# ---------------------------------------------------------------------------- servers
D=/tmp/ui; mkdir -p "$D"
mkcert(){ openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 30 -subj "/CN=$1" \
            -keyout "$D/$1.key" -out "$D/$1.crt" > /dev/null 2>&1; }
mkcert api; mkcert ui
FP=$(openssl x509 -in "$D/api.crt" -noout -fingerprint -sha256 | cut -d= -f2)
python3 "$SRC/tests/ui/fake-pve-api.py" 8006 "$D/api.crt" "$D/api.key" 2> "$D/api.log" &
conf(){ # port tls fingerprint listen
  cat > "$D/$1.json" <<EOF
{"listen": "$4", "port": $1, "tls": $2, "cert": "$D/ui.crt", "key": "$D/ui.key", "node": "pve1",
 "host": "127.0.0.1", "api_port": 8006, "api_fingerprint": "$3", "ssh_key": "$D/id_ed25519",
 "known_hosts": "$D/known_hosts", "ssh_cmd": "/usr/local/mockbin/ui-ssh"}
EOF
}
waitup(){ for _ in $(seq 50); do curl -sk -o /dev/null "$1" && return 0; /bin/sleep 0.2; done; return 1; }

if [ "${UI_DEMO:-}" = 1 ]; then
  echo 1 > "$MOCK/delay"           # slows the runs down, so the live view has something to show
  conf 8443 false "$FP" 0.0.0.0
  echo "web UI: http://localhost:8443  -  root / test-root-pw (realm pam), see tests/ui/fake-pve-api.py"
  PVEAU_UI_CONF="$D/8443.json" exec python3 "$SRC/ui/pve-autoupdate-ui.py"
fi

conf 8443 true "$FP" 127.0.0.1
conf 8444 true "00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF" 127.0.0.1
PVEAU_UI_CONF="$D/8443.json" python3 "$SRC/ui/pve-autoupdate-ui.py" 2> "$D/ui.log" &
PVEAU_UI_CONF="$D/8444.json" python3 "$SRC/ui/pve-autoupdate-ui.py" 2> "$D/ui-badpin.log" &

# ---------------------------------------------------------------------------- helpers
PASS=0; FAILED=0
ok(){ PASS=$((PASS+1)); echo "  ok   $1"; }
bad(){ FAILED=$((FAILED+1)); echo "  FAIL $1"; }
check(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
J(){ python3 -c "import json,sys; d=json.load(open('${3:-/tmp/b}')); sys.exit(0 if ($1) else 1)" 2>/dev/null && test "$CODE" = "$2"; }
U=https://127.0.0.1:8443
JAR=/tmp/jar
# req METHOD PATH [JSON] [curl args ...] - body in /tmp/b, headers in /tmp/h, status in $CODE
req(){
  local m="$1" p="$2" d="${3-}"; shift 2; [ $# -gt 0 ] && shift
  local a=(-sk --path-as-is -o /tmp/b -D /tmp/h -w '%{http_code}' -b "$JAR" -c "$JAR" -X "$m")
  [ -n "$d" ] && a+=(-H 'Content-Type: application/json' --data-binary "$d")
  CODE=$(curl "${a[@]}" "$@" "${URL:-$U}$p")
}
login(){ req POST /api/login "{\"username\":\"$1\",\"password\":\"$2\",\"realm\":\"${3:-pam}\"}"; }
csrf(){ req GET /api/session; CS=$(python3 -c "import json; print(json.load(open('/tmp/b'))['csrf'])" 2>/dev/null); }
post(){ local d="${2-}"; [ -n "$d" ] || d='{}'; req POST "$1" "$d" -H "X-PVEAU-CSRF: $CS"; }
run_of(){ RUN=$(python3 -c "import json; print(json.load(open('/tmp/b')).get('run',''))" 2>/dev/null); }
wait_end(){ for _ in $(seq 120); do req GET "/api/events?run=$1&from=0"; grep -q '"ev": "end"' /tmp/b && return 0; /bin/sleep 0.5; done; return 1; }
wait_idle(){ for _ in $(seq 60); do $AU inventory 2>/dev/null | grep -q '"running": false' && return 0; /bin/sleep 0.5; done; return 1; }

echo "== UI: start"
check "UI answers on 8443 (TLS)"         waitup $U/
check "second UI with a wrong pin"       waitup https://127.0.0.1:8444/

echo "== UI: static files + headers"
req GET /
check "index.html"                       bash -c "test $CODE = 200 && grep -q 'src=\"app.js\"' /tmp/b"
check "strict CSP, no framing"           bash -c "grep -qi \"^content-security-policy: default-src 'self'.*script-src 'self'\" /tmp/h && grep -qi '^x-frame-options: DENY' /tmp/h"
req GET /app.js
check "app.js as javascript"             bash -c "test $CODE = 200 && grep -qi '^content-type: text/javascript' /tmp/h"
for p in /../pve-autoupdate-ui.py /%2e%2e/pve-autoupdate-ui.py /.hidden /config.json /static/app.js; do
  req GET "$p"; check "404 for $p" test "$CODE" = 404
done

echo "== UI: login"
req GET /api/session
check "no session -> 401 + node name"    J 'd["node"]=="pve1"' 401
req GET /api/inventory
check "API needs a session"              test "$CODE" = 401
req GET /api/realms
check "realms from the Proxmox API"      J '[r["realm"] for r in d]==["pam","pve"]' 200
login root wrong-pw
check "wrong password -> 401"            J 'd["error"]=="bad_login"' 401
CODE=$(curl -sk -o /tmp/b -w '%{http_code}' -X POST -H 'Content-Type: text/plain' --data 'username=root' $U/api/login)
check "form posts refused (JSON only)"   test "$CODE" = 400
head -c 70000 /dev/zero | tr '\0' a > /tmp/big
CODE=$(curl -sk -o /tmp/b -w '%{http_code}' -X POST -H 'Content-Type: application/json' --data-binary @/tmp/big $U/api/login)
check "oversized body refused"           test "$CODE" = 400
login nobody test-nobody-pw pve
check "no Sys.Audit -> 403"              J 'd["error"]=="no_permission"' 403
login root test-root-pw pam
check "root@pam logs in"                 J 'd["ok"]' 200
check "cookie HttpOnly, Strict, Secure"  grep -qi '^set-cookie: pveau_session=.*; HttpOnly; SameSite=Strict; Secure' /tmp/h
req GET /api/session
check "session: user, write, csrf"       J 'd["user"]=="root@pam" and d["write"] is True and len(d["csrf"])>20' 200
CS=$(python3 -c "import json; print(json.load(open('/tmp/b'))['csrf'])")

echo "== UI: reading"
req GET /api/inventory
check "inventory: cluster + 2 nodes"     J 'd["cluster"]=="homelab" and [n["name"] for n in d["nodes"]]==["pve1","pve2"]' 200
check "inventory: guests + os"           J 'len(d["guests"])==8 and {g["id"]:g["os"] for g in d["guests"]}[200]=="win11"' 200
check "inventory: last results"          J 'd["last"]["LXC:102"]["update"]["status"]=="ROLLBACK" and d["last"]["NODE:pve2"]["check"]["status"]=="TEST"' 200
check "inventory: no SMTP password"      J '"SMTP_PASS" not in d["config"]' 200
check "ssh: key only, host key checked"  bash -c "grep -q 'BatchMode=yes' /tmp/ssh-args && grep -q 'StrictHostKeyChecking=yes' /tmp/ssh-args && grep -q 'root@127.0.0.1 inventory' /tmp/ssh-args"
req GET "/api/history?n=10"
check "history: 2 runs from the console" J 'len(d)==2 and d[0]["mode"]=="live" and d[1]["mode"]=="dryrun" and d[0].get("trigger")!="ui"' 200
req GET "/api/history?n=1;id"
check "history: junk n -> default"       J 'len(d)==2' 200
req GET /api/log
check "log as text"                      bash -c "test $CODE = 200 && grep -qi '^content-type: text/plain' /tmp/h && test -s /tmp/b"
req GET "/api/events?run=../../etc/passwd&from=0"
check "events: bad run id -> 400"        test "$CODE" = 400

echo "== UI: starting runs"
req POST /api/start '{"mode":"check"}'
check "start without CSRF -> 403"        J 'd["error"]=="csrf"' 403
req POST /api/start '{"mode":"check"}' -H "X-PVEAU-CSRF: wrong"
check "start with wrong CSRF -> 403"     J 'd["error"]=="csrf"' 403
post /api/start '{"mode":"check","targets":["101;reboot"]}'
check "bad targets -> 400"               J 'd["error"]=="bad targets"' 400
post /api/start '{"mode":"check","targets":["101 --purge"]}'
check "targets with spaces -> 400"       test "$CODE" = 400

post /api/start '{"mode":"check","targets":[101,"node:pve2"]}'
run_of
check "check 101 + pve2 started"         J 'd["ok"] and len(d["run"])==15' 200
check "check: run finishes"              wait_end "$RUN"
check "check: TEST for 101 and pve2"     J 'sorted((e["kind"],e["status"]) for e in d["events"] if e["ev"]=="result")==[("LXC","TEST"),("NODE","TEST")]' 200
check "check: marked as from the UI"     J 'd["events"][0]["trigger"]=="ui" and d["events"][0]["mode"]=="dryrun"' 200
req GET "/api/events?run=$RUN&from=3"
check "events: from=3 continues"         python3 -c "import json; d=json.load(open('/tmp/b')); assert d['events'] and d['next']==3+len(d['events'])"
wait_idle

echo 1 > "$MOCK/delay"
post /api/start '{"mode":"update","targets":[101],"reboot":"no"}'
run_of; R2=$RUN
check "update 101 started"               J 'd["ok"]' 200
for _ in $(seq 30); do $AU inventory 2>/dev/null | grep -q '"running": true' && break; /bin/sleep 0.2; done
post /api/start '{"mode":"check"}'
check "second start -> 409 running"      J 'd["error"]=="already running"' 409
req GET /api/inventory
check "inventory: running"               J 'd["running"] is True and d["last_run"]=="'"$R2"'"' 200
rm -f "$MOCK/delay"
check "update: run finishes"             wait_end "$R2"
check "update: 101 OK"                   J '[(e["id"],e["status"]) for e in d["events"] if e["ev"]=="result"]==[("101","OK")]' 200
wait_idle

echo "08:00" > /tmp/clock
post /api/start '{"mode":"update","targets":[104],"reboot":"no"}'
run_of; wait_end "$RUN"
check "outside the window: nothing done" J 'not [e for e in d["events"] if e["ev"]=="result"] and d["events"][-1]["status"]=="window"' 200
wait_idle
post /api/start '{"mode":"update","targets":[104],"reboot":"no","ignore_window":true}'
run_of; wait_end "$RUN"
check "ignore_window: 104 updated"       J '[(e["id"],e["status"]) for e in d["events"] if e["ev"]=="result"]==[("104","OK")]' 200
wait_idle
echo "03:00" > /tmp/clock
req GET "/api/history?n=10"
check "history: UI runs on top"          J 'len(d)==6 and d[0]["trigger"]=="ui" and d[0]["only"]=="104"' 200

echo "== UI: settings + mail"
post /api/config '{"NOTIFY":"always","UPDATE_WINDOW":"01:00-05:30"}'
check "config: saved"                    J 'd["ok"] and sorted(d["changed"])==["NOTIFY","UPDATE_WINDOW"]' 200
check "config: in the node config"       grep -qx 'UPDATE_WINDOW=01:00-05:30' /etc/pve-autoupdate/config
post /api/config '{"SNAPSHOT":"sometimes"}'
check "config: bad value -> 400"         J 'not d["ok"] and "SNAPSHOT" in d["error"]' 400
post /api/config '{"EVIL":"$(id)"}'
check "config: unknown key -> 400"       test "$CODE" = 400
post /api/test-mail
check "test mail"                        J 'd["ok"]' 200

echo "== UI: node down"
touch /tmp/node-down
req GET /api/inventory
check "inventory -> 502 with reason"     J 'd["error"]=="node" and "refused" in d["detail"]' 502
rm -f /tmp/node-down

echo "== UI: logout"
OLD=$(grep pveau_session "$JAR" | awk '{print $NF}')
req POST /api/logout
check "logout"                           J 'd["ok"]' 200
CODE=$(curl -sk -o /tmp/b -w '%{http_code}' -H "Cookie: pveau_session=$OLD" $U/api/inventory)
check "old cookie is dead"               test "$CODE" = 401

echo "== UI: read-only account"
JAR=/tmp/jar2
login viewer test-view-pw pve
check "viewer@pve logs in"               J 'd["ok"]' 200
csrf
req GET /api/session
check "session: read only"               J 'd["write"] is False' 200
req GET /api/inventory
check "viewer can read"                  test "$CODE" = 200
post /api/start '{"mode":"check"}'
check "viewer cannot start -> 403"       J 'd["error"]=="read_only"' 403
post /api/config '{"NOTIFY":"never"}'
check "viewer cannot change settings"    J 'd["error"]=="read_only"' 403

echo "== UI: two-factor"
JAR=/tmp/jar3
login tfa test-tfa-pw pve
check "tfa user -> asks for a code"      J 'd["tfa"] is True and d["pending"]' 200
check "no cookie before the code"        bash -c "! grep -qi '^set-cookie' /tmp/h"
P=$(python3 -c "import json; print(json.load(open('/tmp/b'))['pending'])")
req POST /api/login "{\"pending\":\"$P\",\"code\":\"654321\"}"
check "wrong code -> 401"                J 'd["error"]=="bad_code"' 401
req POST /api/login "{\"pending\":\"$P\",\"code\":\"123456\"}"
check "challenge is single use"          J 'd["error"]=="expired"' 401
login tfa test-tfa-pw pve
P=$(python3 -c "import json; print(json.load(open('/tmp/b'))['pending'])")
req POST /api/login "{\"pending\":\"$P\",\"code\":\"123456\"}"
check "right TOTP code -> session"       bash -c "test $CODE = 200 && grep -qi '^set-cookie: pveau_session=.' /tmp/h"
JAR=/tmp/jar4
login tfa test-tfa-pw pve
P=$(python3 -c "import json; print(json.load(open('/tmp/b'))['pending'])")
req POST /api/login "{\"pending\":\"$P\",\"code\":\"0a1b-2c3d-4e5f-6a7b\"}"
check "recovery key -> session"          test "$CODE" = 200

echo "== UI: certificate pin"
URL=https://127.0.0.1:8444 login root test-root-pw pam
check "wrong API fingerprint -> 502"     J '"pinned fingerprint" in d["detail"]' 502

echo "== UI: brute force"
JAR=/tmp/jar5
for _ in 1 2 3 4 5 6; do login root nope pam; done
check "too many failures -> 429"         J 'd["error"]=="too_many_attempts"' 429
login root test-root-pw pam
check "blocks the right password too"    test "$CODE" = 429

check "UI log has no passwords"          bash -c "! grep -q 'test-.*-pw' $D/ui.log"
echo
echo "passed: $PASS  failed: $FAILED"
[ "$FAILED" = 0 ]
