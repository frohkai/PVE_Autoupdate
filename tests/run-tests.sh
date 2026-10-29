#!/usr/bin/env bash
# Runs pve-autoupdate against mocked Proxmox tools (pvesh, pct, qm, ssh, apt-get ...).
# Meant for a throwaway container, it writes to /etc, /var and /usr/local:
#
#   docker run --rm -v "$PWD:/src:ro" alpine sh -c "apk add -q bash python3 && bash /src/tests/run-tests.sh"
#
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SRC/pve-autoupdate.sh"
export MOCK=/tmp/mock
mkdir -p /usr/local/mockbin && cp "$SRC"/tests/mocks/* /usr/local/mockbin/ && chmod +x /usr/local/mockbin/*
export PATH="/usr/local/mockbin:$PATH"
mkdir -p /etc/pve /run/systemd/system /etc/systemd/system /boot /var/run

PASS=0; FAILED=0
ok(){ PASS=$((PASS+1)); echo "  ok   $1"; }
bad(){ FAILED=$((FAILED+1)); echo "  FAIL $1"; }
check(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
has(){ grep -E -- "$2" "$1"; }

reset(){
  rm -rf "$MOCK" /etc/pve-autoupdate /var/lib/pve-autoupdate /var/log/pve-autoupdate.log /tmp/appver.* /boot/vmlinuz-*
  mkdir -p "$MOCK/beh" "$MOCK/state"; : > "$MOCK/actions"
}
single_node(){ echo '[{"type":"node","name":"pve1","ip":"10.0.0.1","online":1,"local":1}]' > "$MOCK/cluster.json"; }
two_nodes(){ cat > "$MOCK/cluster.json" <<'EOF'
[{"type":"cluster","name":"homelab","nodes":2,"quorate":1},
 {"type":"node","name":"pve1","ip":"10.0.0.1","online":1,"local":1},
 {"type":"node","name":"pve2","ip":"10.0.0.2","online":1,"local":0}]
EOF
}
config(){ mkdir -p /etc/pve-autoupdate/services.d; printf '%s\n' "$@" > /etc/pve-autoupdate/config; }

# ----------------------------------------------------------------------------
echo "== syntax"
check "bash -n" bash -n "$SCRIPT"
check "help (en)" bash -c "bash '$SCRIPT' help | grep -q 'run updates now'"
check "help (de)" bash -c "PVE_AUTOUPDATE_LANG=de bash '$SCRIPT' help | grep -q 'Updates jetzt ausführen'"
check "runner is POSIX sh" bash -c "sed -n \"/^read -r -d '' RUNNER_HEAD/,/^RUNNER_EOF/p\" '$SCRIPT' | sed '1d;\$d' > /tmp/r.sh && sh -n /tmp/r.sh"

# ----------------------------------------------------------------------------
echo "== A: single node, live run, english"
reset; single_node
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":101,"type":"lxc","name":"web","node":"pve1","status":"running","template":0},
 {"vmid":102,"type":"lxc","name":"db","node":"pve1","status":"running","template":0},
 {"vmid":103,"type":"lxc","name":"old","node":"pve1","status":"stopped","template":0},
 {"vmid":104,"type":"lxc","name":"backup-running","node":"pve1","status":"running","template":0},
 {"vmid":105,"type":"lxc","name":"dir-storage","node":"pve1","status":"running","template":0},
 {"vmid":106,"type":"lxc","name":"dpkg-broken","node":"pve1","status":"running","template":0},
 {"vmid":107,"type":"lxc","name":"no-repo","node":"pve1","status":"running","template":0},
 {"vmid":108,"type":"lxc","name":"myapp","node":"pve1","status":"running","template":0},
 {"vmid":200,"type":"qemu","name":"windows","node":"pve1","status":"running","template":0},
 {"vmid":201,"type":"qemu","name":"no-agent","node":"pve1","status":"running","template":0},
 {"vmid":202,"type":"qemu","name":"linux-vm","node":"pve1","status":"running","template":0},
 {"vmid":900,"type":"lxc","name":"tmpl","node":"pve1","status":"stopped","template":1}]
EOF
echo "PKGS=3" > "$MOCK/beh/101"
echo "PKGS=2 BREAK=1" > "$MOCK/beh/102"
touch "$MOCK/beh/104.lock"
echo "PKGS=1" > "$MOCK/beh/105"; touch "$MOCK/beh/105.nosnap"
echo "PKGS=4 FAIL=1" > "$MOCK/beh/106"
echo "REFFAIL=1" > "$MOCK/beh/107"
echo "win11" > "$MOCK/beh/200.ostype"
touch "$MOCK/beh/201.noagent"
echo "PKGS=2" > "$MOCK/beh/202"
echo "PKGS=5" > "$MOCK/beh/node-local"
config "UI_LANG=en" "GUESTS=all" "INCLUDE_VMS=1" "UPDATE_HOSTS=1" "SNAPSHOT=optional" "NOTIFY=errors" "MAIL_TO=me@example.com" "REBOOT_HOSTS=0" "TITLE=homelab" "UPDATE_WINDOWS=0"
cat > /etc/pve-autoupdate/services.d/myapp.conf <<'EOF'
NAME="MyApp"
TARGET="108"
VERSION_CMD='cat /tmp/appver.$MOCK_GUEST 2>/dev/null || echo 1.0'
UPDATE_CMD='echo 1.1 > /tmp/appver.$MOCK_GUEST'
HEALTH_CMD='true'
EOF
bash "$SCRIPT" run > /tmp/a.out 2>&1; rc=$?
check "exit code 0 (no FAIL)"            test "$rc" = 0
check "101 OK, 3 packages"               has /tmp/a.out '^LXC  101 .*OK .*3 packages updated'
check "102 broken unit -> ROLLBACK"      has /tmp/a.out '^LXC  102 .*ROLLBACK .*newly failed services: broken.service) - rolled'
check "103 stopped -> SKIP"              has /tmp/a.out '^LXC  103 .*SKIP .*not running'
check "104 locked -> WARN"               has /tmp/a.out '^LXC  104 .*WARN .*locked'
check "105 no snapshot -> OK"            has /tmp/a.out '^LXC  105 .*OK .*without snapshot'
check "106 dpkg error -> ROLLBACK"       has /tmp/a.out '^LXC  106 .*ROLLBACK .*package upgrade failed'
check "107 repo error -> WARN"           has /tmp/a.out '^LXC  107 .*WARN .*package sources unreachable'
check "108 custom service 1.0 -> 1.1"    has /tmp/a.out '^LXC  108 .*OK .*MyApp 1.0 -> 1.1'
check "200 windows switched off -> SKIP" has /tmp/a.out "^VM   200 .*SKIP .*Windows updates are switched off"
check "201 no agent -> SKIP"             has /tmp/a.out '^VM   201 .*SKIP .*guest agent'
check "202 VM via agent -> OK"           has /tmp/a.out '^VM   202 .*OK .*2 packages updated'
check "node updated"                     has /tmp/a.out '^NODE pve1 .*OK .*5 packages updated'
check "template ignored"                 bash -c "! grep -q tmpl /tmp/a.out"
check "rollback 102 + 106"               bash -c "grep -q 'pct rollback 102 autoupdate' $MOCK/actions && grep -q 'pct rollback 106 autoupdate' $MOCK/actions"
check "snapshot 101 deleted"             has "$MOCK/actions" 'pct delsnapshot 101 autoupdate'
check "locked 104 not touched"           bash -c "! grep -q 'pct snapshot 104' $MOCK/actions"
check "mail sent"                        test -f "$MOCK/mail.1"
check "mail subject rolled back"         has "$MOCK/mail.1" '^Subject: .*rolled back'
check "mail has html part"               has "$MOCK/mail.1" 'text/html'
check "donate link in mail"            bash -c "python3 -c 'import email; m=email.message_from_file(open(\"$MOCK/mail.1\")); print(\"\".join((p.get_payload(decode=True) or b\"\").decode(\"utf-8\",\"replace\") for p in m.walk() if p.get_content_maintype()==\"text\"))' | grep -q 'liberapay.com/Viollent_Tech/donate'"
cp "$MOCK/mail.1" /tmp/mail-en.eml

# ----------------------------------------------------------------------------
echo "== B: dry run, german, with --mail"
: > "$MOCK/actions"; rm -f "$MOCK"/mail.* /tmp/appver.*
config "UI_LANG=de" "GUESTS=all" "INCLUDE_VMS=1" "UPDATE_HOSTS=1" "SNAPSHOT=optional" "NOTIFY=errors" "MAIL_TO=me@example.com"
bash "$SCRIPT" run --dry-run --mail > /tmp/b.out 2>&1
check "TEST status"                      has /tmp/b.out '^LXC  101 .*TEST .*3 Pakete verfügbar'
check "no snapshot, no upgrade"          bash -c "! grep -qE 'snapshot|dist-upgrade|rollback' $MOCK/actions"
check "german mail subject [TEST]"       bash -c "python3 -c 'import email,sys; m=email.message_from_file(open(\"$MOCK/mail.1\")); print(str(email.header.make_header(email.header.decode_header(m[\"Subject\"]))))' | grep -q '^\[TEST\].*Warnung'"
check "german html"                      bash -c "python3 -c 'import email; m=email.message_from_file(open(\"$MOCK/mail.1\")); print([p.get_payload(decode=True).decode() for p in m.walk() if p.get_content_type()==\"text/html\"][0])' | grep -q 'TESTLAUF'"
cp "$MOCK/mail.1" /tmp/mail-de.eml

# ----------------------------------------------------------------------------
echo "== C: two-node cluster, rolling reboot"
reset; two_nodes
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":101,"type":"lxc","name":"web","node":"pve1","status":"running","template":0},
 {"vmid":301,"type":"lxc","name":"remote-ct","node":"pve2","status":"running","template":0}]
EOF
echo "PKGS=1" > "$MOCK/beh/301"
echo "PKGS=7" > "$MOCK/beh/node-pve2"; echo "PKGS=7" > "$MOCK/beh/node-local"
touch /boot/vmlinuz-99.0-pve          # newer kernel installed -> reboot needed
config "UI_LANG=en" "GUESTS=all" "UPDATE_HOSTS=1" "REBOOT_HOSTS=1" "NOTIFY=always" "MAIL_TO=me@example.com"
bash "$SCRIPT" run > /tmp/c.out 2>&1
check "guest on pve2 via ssh"            has /tmp/c.out '^LXC  301 .*pve2 .*OK'
check "pve2 updated"                     has /tmp/c.out '^NODE pve2 .*OK .*7 packages'
check "pve2 rebooted first"              bash -c "grep -n REBOOT $MOCK/actions | head -n1 | grep -q pve2"
check "self rebooted last"               bash -c "grep REBOOT $MOCK/actions | tail -n1 | grep -q SELF"
check "reboot-pending flag"              test -f /var/lib/pve-autoupdate/reboot-pending
rm -f "$MOCK"/mail.*
bash "$SCRIPT" postcheck boot > /tmp/c2.out 2>&1
check "postcheck clears flag"            test ! -f /var/lib/pve-autoupdate/reboot-pending
check "postcheck mail: back online"      has "$MOCK/mail.1" 'back online'
check "events: run ended 'rebooting'"    bash -c "grep -q '\"status\": \"rebooting\"' /var/lib/pve-autoupdate/runs/\$(cat /var/lib/pve-autoupdate/last-run).jsonl"
check "events: postcheck added to run"   bash -c "grep -q '\"ev\": \"postcheck\".*\"problems\": \"0\"' /var/lib/pve-autoupdate/runs/\$(cat /var/lib/pve-autoupdate/last-run).jsonl"

# ----------------------------------------------------------------------------
echo "== D: snapshot required, node offline"
reset; two_nodes
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":105,"type":"lxc","name":"dir-storage","node":"pve1","status":"running","template":0},
 {"vmid":301,"type":"lxc","name":"remote-ct","node":"pve2","status":"running","template":0}]
EOF
python3 - <<'EOF'
import json; p="/tmp/mock/cluster.json"; d=json.load(open(p))
for r in d:
    if r.get("name")=="pve2": r["online"]=0
json.dump(d, open(p,"w"))
EOF
touch "$MOCK/beh/105.nosnap"; echo "PKGS=1" > "$MOCK/beh/105"
config "UI_LANG=en" "GUESTS=all" "UPDATE_HOSTS=0" "SNAPSHOT=required" "NOTIFY=never"
bash "$SCRIPT" run > /tmp/d.out 2>&1
check "required snapshot -> skipped"     has /tmp/d.out '^LXC  105 .*WARN .*snapshot not possible'
check "no upgrade without snapshot"      bash -c "! grep -q 'dist-upgrade 105' $MOCK/actions"
check "offline node -> WARN"             has /tmp/d.out '^LXC  301 .*WARN .*not reachable'
check "NOTIFY=never -> no mail"          bash -c "! ls $MOCK/mail.* 2>/dev/null"

# ----------------------------------------------------------------------------
echo "== E: lock"
exec 8>/run/pve-autoupdate.lock; flock -n 8
bash "$SCRIPT" run > /tmp/e.out 2>&1; rc=$?
check "second run refused"               bash -c "test $rc != 0 && grep -q 'already running' /tmp/e.out"
exec 8>&-
bash "$SCRIPT" run --dry-run > /tmp/e2.out 2>&1
check "lock released afterwards"         bash -c "! grep -q 'already running' /tmp/e2.out"

# ----------------------------------------------------------------------------
echo "== G: Windows VMs (Windows Update via guest agent)"
reset; single_node
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":300,"type":"qemu","name":"win-ok","node":"pve1","status":"running","template":0},
 {"vmid":301,"type":"qemu","name":"win-break","node":"pve1","status":"running","template":0},
 {"vmid":302,"type":"qemu","name":"win-noboot","node":"pve1","status":"running","template":0},
 {"vmid":303,"type":"qemu","name":"win-current","node":"pve1","status":"running","template":0},
 {"vmid":304,"type":"qemu","name":"win-wuerror","node":"pve1","status":"running","template":0},
 {"vmid":305,"type":"qemu","name":"win-partial","node":"pve1","status":"running","template":0},
 {"vmid":306,"type":"qemu","name":"win-hang","node":"pve1","status":"running","template":0},
 {"vmid":307,"type":"qemu","name":"win-noagent","node":"pve1","status":"running","template":0}]
EOF
for v in 300 301 302 303 304 305 306 307; do echo "win11" > "$MOCK/beh/$v.ostype"; done
echo "WUPD=3 WUPD2=1 WREBOOT=1"       > "$MOCK/beh/300.win"
echo "WUPD=2 WREBOOT=1 WBREAK=1"      > "$MOCK/beh/301.win"
echo "WUPD=1 WREBOOT=1 WNOBOOT=1"     > "$MOCK/beh/302.win"
echo "WUPD=0"                         > "$MOCK/beh/303.win"
echo "WERR=0x8024402C_no_connection"  > "$MOCK/beh/304.win"
echo "WUPD=3 WFAIL=1"                 > "$MOCK/beh/305.win"
echo "WUPD=1 WHANG=1"                 > "$MOCK/beh/306.win"
touch "$MOCK/beh/307.noagent"
cp -R "$MOCK/beh" /tmp/beh-g
config "UI_LANG=en" "GUESTS='300 301 302 303 304 305 306 307'" "UPDATE_HOSTS=0" "SNAPSHOT=optional" "REBOOT_GUESTS=1" \
       "NOTIFY=always" "MAIL_TO=me@example.com" "SETTLE=0" "WIN_REBOOT_TIMEOUT=1" "WIN_UPDATE_TIMEOUT=1"
bash "$SCRIPT" run > /tmp/g.out 2>&1
check "300 4 updates in 2 rounds, rebooted" has /tmp/g.out '^VM   300 .*OK .*4 Windows updates installed \(KB5044280, KB5044281, KB5044282, KB5044290\), rebooted'
check "300 rebooted twice"               test "$(grep -c '^win 300 reboot' "$MOCK/actions")" = 2
check "300 snapshot deleted"             has "$MOCK/actions" 'qm delsnapshot 300 autoupdate'
check "300 no extra reboot afterwards"   bash -c "! grep -q 'qm reboot 300' $MOCK/actions"
check "301 service gone -> ROLLBACK"     has /tmp/g.out '^VM   301 .*ROLLBACK .*services no longer running: MyApp'
check "301 tried to start it first"      has "$MOCK/actions" '^win 301 start'
check "301 rolled back"                  has "$MOCK/actions" 'qm rollback 301 autoupdate'
check "302 not back -> ROLLBACK"         has /tmp/g.out '^VM   302 .*ROLLBACK .*did not come back within 1 min'
check "303 up to date, no reboot"        bash -c "grep -qE '^VM   303 .*OK .*up to date' /tmp/g.out && ! grep -q '^win 303 reboot' $MOCK/actions"
check "304 WU error -> WARN, no rollback" bash -c "grep -qE '^VM   304 .*WARN .*0x8024402C no connection' /tmp/g.out && ! grep -q 'qm rollback 304' $MOCK/actions"
check "305 partial -> WARN"              has /tmp/g.out '^VM   305 .*WARN .*2 Windows updates installed.*1 failed'
check "305 no reboot asked"              bash -c "! grep -q '^win 305 reboot' $MOCK/actions"
check "306 hanging install -> ROLLBACK"  has /tmp/g.out '^VM   306 .*ROLLBACK .*did not finish within 1 min'
check "307 no agent -> WARN"             has /tmp/g.out '^VM   307 .*WARN .*guest agent'
check "mail lists Windows updates"       bash -c "python3 -c 'import email; m=email.message_from_file(open(\"$MOCK/mail.1\")); print([p.get_payload(decode=True).decode() for p in m.walk() if p.get_content_type()==\"text/html\"][0])' | grep -q '4 Windows updates installed'"

reset; single_node; cp /tmp/beh-g/300.* "$MOCK/beh/"
echo '[{"vmid":300,"type":"qemu","name":"win-ok","node":"pve1","status":"running","template":0}]' > "$MOCK/resources.json"
config "UI_LANG=de" "GUESTS=300" "UPDATE_HOSTS=0" "NOTIFY=never"
bash "$SCRIPT" run --dry-run > /tmp/g2.out 2>&1
check "dry run (de): updates available"  has /tmp/g2.out '^VM   300 .*TEST .*3 Windows-Updates verfügbar \(KB5044280, KB5044281, KB5044282\)'
check "dry run: nothing installed"       bash -c "! grep -qE 'win 300 (install|reboot)|qm snapshot' $MOCK/actions"
config "UI_LANG=en" "GUESTS=300" "UPDATE_HOSTS=0" "NOTIFY=never" "UPDATE_WINDOWS=0"
bash "$SCRIPT" run > /tmp/g3.out 2>&1
check "UPDATE_WINDOWS=0 -> SKIP"         has /tmp/g3.out '^VM   300 .*SKIP .*switched off'

# ----------------------------------------------------------------------------
echo "== H: control interface for the web UI (JSON, remote, pair)"
reset; single_node
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":101,"type":"lxc","name":"web","node":"pve1","status":"running","template":0},
 {"vmid":102,"type":"lxc","name":"db","node":"pve1","status":"running","template":0},
 {"vmid":110,"type":"lxc","name":"excluded","node":"pve1","status":"running","template":0}]
EOF
echo "PKGS=3" > "$MOCK/beh/101"; echo "PKGS=2" > "$MOCK/beh/102"; echo "PKGS=5" > "$MOCK/beh/node-local"
mkdir -p /etc/pve/nodes/pve1/lxc
printf 'ostype: debian\nhostname: web\n[autoupdate]\nostype: alpine\n' > /etc/pve/nodes/pve1/lxc/101.conf
config "UI_LANG=en" "GUESTS=all" "EXCLUDE=110" "UPDATE_HOSTS=1" "NOTIFY=never" "SMTP_PASS=secret" "SETTLE=0"
J(){ python3 -c "import json,sys; d=json.load(open('$1')); sys.exit(0 if ($2) else 1)"; }
R=/var/lib/pve-autoupdate/runs

bash "$SCRIPT" run > /tmp/h1.out 2>&1
id1=$(cat /var/lib/pve-autoupdate/last-run)
check "run writes an event file"         test -s "$R/$id1.jsonl"
check "events: start, results, end"      bash -c "head -n1 $R/$id1.jsonl | grep -q '\"ev\": \"start\"' && grep -c '\"ev\": \"result\"' $R/$id1.jsonl | grep -qx 3 && tail -n1 $R/$id1.jsonl | grep -q '\"status\": \"ok\"'"
check "events are valid JSON"            python3 -c "import json; [json.loads(l) for l in open('$R/$id1.jsonl')]"

: > "$MOCK/actions"
bash "$SCRIPT" run --only 101 > /tmp/h2.out 2>&1
check "--only 101: just that guest"      bash -c "grep -q '^LXC  101' /tmp/h2.out && ! grep -qE '^(LXC  102|NODE)' /tmp/h2.out"
bash "$SCRIPT" run --only node:pve1 --dry-run > /tmp/h3.out 2>&1
check "--only node:pve1: just the node"  bash -c "grep -q '^NODE pve1' /tmp/h3.out && ! grep -q '^LXC' /tmp/h3.out"
bash "$SCRIPT" run --only '101;reboot' > /tmp/h4.out 2>&1; rc=$?
check "--only rejects junk"              bash -c "test $rc != 0 && grep -q 'invalid target' /tmp/h4.out"

bash "$SCRIPT" history > /tmp/h5.json 2>/dev/null
check "history: 3 runs, newest first"    J /tmp/h5.json 'len(d)==3 and d[0]["mode"]=="dryrun" and d[0]["only"]=="node:pve1" and d[2]["status"]=="ok" and d[2]["results"]==3'
bash "$SCRIPT" events "$id1" 2 > /tmp/h6.out
check "events from line 2"               test "$(wc -l < /tmp/h6.out)" = "$(( $(wc -l < "$R/$id1.jsonl") - 2 ))"
check "events: bad id refused"           bash -c "bash '$SCRIPT' events '../../etc/passwd' | grep -q 'invalid run id'"

bash "$SCRIPT" inventory > /tmp/h7.json 2>/dev/null
check "inventory is JSON with guests"    J /tmp/h7.json 'len(d["guests"])==3 and d["nodes"][0]["name"]=="pve1"'
check "inventory: selection + os"        J /tmp/h7.json '[g["selected"] for g in d["guests"]]==[True,True,False] and d["guests"][0]["os"]=="debian"'
check "inventory: no SMTP password"      J /tmp/h7.json '"SMTP_PASS" not in d["config"] and d["smtp_pass_set"] is True and d["running"] is False'

echo '{"NOTIFY":"always","MAIL_TO":"me@example.com","REBOOT_HOSTS":true,"GUESTS":[101,102],"TITLE":"$(touch /tmp/pwned)"}' | bash "$SCRIPT" config set > /tmp/h8.json 2>/dev/null
check "config set: ok + changed keys"    J /tmp/h8.json 'd["ok"] and sorted(d["changed"])==["GUESTS","MAIL_TO","NOTIFY","REBOOT_HOSTS","TITLE"]'
check "config set: written"              bash -c "grep -qx 'NOTIFY=always' /etc/pve-autoupdate/config && grep -qx 'GUESTS=101\\\\ 102' /etc/pve-autoupdate/config && grep -qx 'SMTP_PASS=secret' /etc/pve-autoupdate/config"
bash "$SCRIPT" status > /dev/null 2>&1
check "config set: no code injection"    test ! -e /tmp/pwned
echo '{"NOTIFY":"never","SNAPSHOT":"sometimes"}' | bash "$SCRIPT" config set > /tmp/h9.json 2>&1; rc=$?
check "config set: bad value refused"    bash -c "test $rc != 0 && grep -q 'invalid value for SNAPSHOT' /tmp/h9.json && grep -qx 'NOTIFY=always' /etc/pve-autoupdate/config"
echo '{"EVIL":"1"}' | bash "$SCRIPT" config set > /tmp/h10.json 2>&1
check "config set: unknown key refused"  grep -q 'invalid value for EVIL' /tmp/h10.json
echo 'not json' | bash "$SCRIPT" config set > /tmp/h11.json 2>&1
check "config set: bad JSON refused"     grep -q 'invalid JSON' /tmp/h11.json

config "UI_LANG=en" "GUESTS=all" "UPDATE_HOSTS=0" "NOTIFY=never" "SETTLE=0"
bash "$SCRIPT" start --dry-run --only=101 > /tmp/h12.json 2>&1
check "start: returns run id"            J /tmp/h12.json 'd["ok"] and len(d["run"])==15'
sid=$(python3 -c "import json; print(json.load(open('/tmp/h12.json'))['run'])" 2>/dev/null)
check "start: runs detached (systemd-run)" has "$MOCK/actions" "systemd-run .*pve-autoupdate-ui-$sid"
check "start: run marked as from UI"     bash -c "head -n1 $R/$sid.jsonl | grep -q '\"trigger\": \"ui\"'"
check "start: bad option refused"        bash -c "bash '$SCRIPT' start --purge | grep -q 'invalid option'"
exec 8>/run/pve-autoupdate.lock; flock -n 8
check "start: refused while running"     bash -c "bash '$SCRIPT' start | grep -q 'already running'"
bash "$SCRIPT" inventory > /tmp/h13.json 2>/dev/null
check "inventory: running flag"          J /tmp/h13.json 'd["running"] is True'
exec 8>&-

# remote = forced command of the paired SSH key
check "remote: inventory allowed"        bash -c "SSH_ORIGINAL_COMMAND=inventory bash '$SCRIPT' remote | python3 -c 'import json,sys; json.load(sys.stdin)'"
check "remote: with program name too"    bash -c "SSH_ORIGINAL_COMMAND='pve-autoupdate version' bash '$SCRIPT' remote | grep -q '^pve-autoupdate '"
for c in "setup" "run" "uninstall --purge" "inventory; id" 'inventory $(id)' "bash" "" "config show" "pair x" "remote"; do
  check "remote: refuses '$c'"           bash -c "SSH_ORIGINAL_COMMAND='$c' bash '$SCRIPT' remote | grep -q 'not allowed'"
done
echo '{"NOTIFY":"errors"}' | SSH_ORIGINAL_COMMAND="config set" bash "$SCRIPT" remote > /dev/null 2>&1
check "remote: config set via stdin"     grep -qx 'NOTIFY=errors' /etc/pve-autoupdate/config

# pair / unpair
mkdir -p /usr/local/sbin; install -m 755 "$SCRIPT" /usr/local/sbin/pve-autoupdate
export PVE_AUTOUPDATE_AUTHKEYS=/tmp/authorized_keys
echo "ssh-rsa AAAAB3other admin@laptop" > /tmp/authorized_keys
K="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5b0x3Qm9yZXN0dGVzdGtleQ== root@pve-autoupdate-ui"
bash "$SCRIPT" pair "$K" > /dev/null 2>&1
bash "$SCRIPT" pair "$K" > /dev/null 2>&1
check "pair: key locked to remote"       grep -qx 'command="/usr/local/sbin/pve-autoupdate remote",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5b0x3Qm9yZXN0dGVzdGtleQ== pve-autoupdate-ui' /tmp/authorized_keys
check "pair: only once, others kept"     bash -c "test \$(grep -c pve-autoupdate-ui /tmp/authorized_keys) = 1 && grep -q admin@laptop /tmp/authorized_keys"
check "pair: rejects junk"               bash -c "! bash '$SCRIPT' pair 'command=\"sh\" ssh-rsa AAA' > /dev/null 2>&1"
bash "$SCRIPT" unpair > /dev/null 2>&1
check "unpair: removed, others kept"     bash -c "! grep -q pve-autoupdate-ui /tmp/authorized_keys && grep -q admin@laptop /tmp/authorized_keys"
unset PVE_AUTOUPDATE_AUTHKEYS
rm -f /usr/local/sbin/pve-autoupdate

# ----------------------------------------------------------------------------
echo "== I: update window"
reset; single_node
cat > "$MOCK/resources.json" <<'EOF'
[{"vmid":101,"type":"lxc","name":"web","node":"pve1","status":"running","template":0},
 {"vmid":102,"type":"lxc","name":"db","node":"pve1","status":"running","template":0}]
EOF
echo "PKGS=3" > "$MOCK/beh/101"; echo "PKGS=2" > "$MOCK/beh/102"; echo "PKGS=5" > "$MOCK/beh/node-local"
export PVE_AUTOUPDATE_CLOCK=/tmp/clock
config "UI_LANG=en" "GUESTS=all" "UPDATE_HOSTS=1" "REBOOT_HOSTS=1" "NOTIFY=never" "SETTLE=0" "UPDATE_WINDOW=02:00-05:00"

echo "06:30" > /tmp/clock
bash "$SCRIPT" run > /tmp/i1.out 2>&1; rc=$?
check "outside: nothing done, exit 0"    bash -c "test $rc = 0 && grep -q 'Outside the update window (02:00-05:00)' /tmp/i1.out && ! grep -q snapshot $MOCK/actions"
bash "$SCRIPT" run --dry-run > /tmp/i2.out 2>&1
check "outside: dry run still works"     has /tmp/i2.out '^LXC  101 .*TEST .*3 packages available'
bash "$SCRIPT" run --ignore-window --only 101 > /tmp/i3.out 2>&1
check "--ignore-window forces it"        has /tmp/i3.out '^LXC  101 .*OK .*3 packages updated'

echo "03:00" > /tmp/clock; : > "$MOCK/actions"; touch /boot/vmlinuz-99.0-pve
bash "$SCRIPT" run > /tmp/i4.out 2>&1
check "inside: guests + node updated"    bash -c "grep -q '^LXC  102 .*OK' /tmp/i4.out && grep -q '^NODE pve1 .*OK' /tmp/i4.out"
check "inside: node reboot allowed"      has "$MOCK/actions" 'REBOOT'
rm -f /var/lib/pve-autoupdate/reboot-pending

# window ends while 101 is being updated (its update moves the clock to 05:10)
echo "04:50" > /tmp/clock; : > "$MOCK/actions"
cat > /etc/pve-autoupdate/services.d/clock.conf <<'EOF'
NAME="Clock"
TARGET="101"
VERSION_CMD='cat /tmp/clockapp 2>/dev/null || echo 1'
UPDATE_CMD='echo 2 > /tmp/clockapp; echo 05:10 > /tmp/clock'
HEALTH_CMD='true'
EOF
bash "$SCRIPT" run > /tmp/i5.out 2>&1
check "window ends: running guest done"  has /tmp/i5.out '^LXC  101 .*OK'
check "window ends: rest waits"          bash -c "grep -q '^LXC  102 .*SKIP .*update window (02:00-05:00) over' /tmp/i5.out && grep -q '^NODE pve1 .*SKIP' /tmp/i5.out"
check "window ends: no reboot"           bash -c "! grep -q REBOOT $MOCK/actions && grep -q 'reboots postponed' /var/log/pve-autoupdate.log"
rm -f /etc/pve-autoupdate/services.d/clock.conf /tmp/clockapp

# across midnight
config "UI_LANG=en" "GUESTS=101" "UPDATE_HOSTS=0" "NOTIFY=never" "SETTLE=0" "UPDATE_WINDOW=23:00-04:00"
echo "23:30" > /tmp/clock; bash "$SCRIPT" run > /tmp/i6.out 2>&1
check "23:00-04:00 at 23:30: runs"       has /tmp/i6.out '^LXC  101 .*OK'
echo "12:00" > /tmp/clock; bash "$SCRIPT" run > /tmp/i7.out 2>&1
check "23:00-04:00 at 12:00: waits"      has /tmp/i7.out 'Outside the update window'
check "status shows the window"          bash -c "bash '$SCRIPT' status | grep -q 'only 23:00 - 04:00'"

echo '{"UPDATE_WINDOW":"25:00-03:00"}' | bash "$SCRIPT" config set > /tmp/i8.json 2>/dev/null
check "config set: bad window refused"   grep -q 'invalid value for UPDATE_WINDOW' /tmp/i8.json
echo '{"UPDATE_WINDOW":"01:30-04:15"}' | bash "$SCRIPT" config set > /tmp/i9.json 2>/dev/null
check "config set: window saved"         grep -qx 'UPDATE_WINDOW=01:30-04:15' /etc/pve-autoupdate/config
echo '{"UPDATE_WINDOW":""}' | bash "$SCRIPT" config set > /dev/null 2>&1
check "config set: window removed"       bash -c "grep -qE \"^UPDATE_WINDOW=(''|)$\" /etc/pve-autoupdate/config"
unset PVE_AUTOUPDATE_CLOCK

# ----------------------------------------------------------------------------
echo "== F: install + uninstall"
mkdir -p /usr/local/sbin; install -m 755 "$SCRIPT" /usr/local/sbin/pve-autoupdate
config "UI_LANG=en" "SCHEDULE='Sat *-*-* 04:30:00'"
/usr/local/sbin/pve-autoupdate setup --apply > /tmp/f.out 2>&1
check "installed binary"                 test -x /usr/local/sbin/pve-autoupdate
check "timer unit written"               grep -qF 'OnCalendar=Sat *-*-* 04:30:00' /etc/systemd/system/pve-autoupdate.timer
/usr/local/sbin/pve-autoupdate uninstall --purge > /tmp/f2.out 2>&1
check "uninstall --purge"                bash -c "test ! -e /usr/local/sbin/pve-autoupdate && test ! -d /etc/pve-autoupdate"

echo
echo "passed: $PASS  failed: $FAILED"
[ "$FAILED" = 0 ]
