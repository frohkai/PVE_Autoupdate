# Simulates a Windows VM behind the QEMU guest agent for the qm mock.
# Decodes the -EncodedCommand script, reads the phase and answers like WIN_PS would.
#
# Behaviour: $MOCK/beh/<id>.win, space separated KEY=VALUE
#   WUPD=n     updates offered in the first round     WUPD2=n  ... after the first reboot
#   WFAIL=n    of those, n fail to install            WREBOOT=1  install needs a reboot
#   WBREAK=1   service "MyApp" no longer runs after a reboot
#   WNOBOOT=1  VM does not come back after a reboot  WHANG=1    install never finishes
#   WERR=text  Windows Update search fails (use _ for spaces)
import base64, json, os, re, sys

MOCK = os.environ["MOCK"]


def beh(vid):
    b, p = {}, "%s/beh/%s.win" % (MOCK, vid)
    if os.path.exists(p):
        for kv in open(p).read().split():
            k, _, v = kv.partition("=")
            b[k] = v
    return b


def get(vid, key, default="0"):
    p = "%s/state/%s.%s" % (MOCK, vid, key)
    return open(p).read().strip() if os.path.exists(p) else default


def put(vid, key, value):
    open("%s/state/%s.%s" % (MOCK, vid, key), "w").write(str(value))


def run(vid, script):
    phase, ignore, names = re.match(r"\$Phase='([^']*)'; \$Ignore='([^']*)'; \$Names='([^']*)'", script).groups()
    with open(MOCK + "/actions", "a") as f:
        f.write("win %s %s\n" % (vid, phase))
    b, boot, rnd = beh(vid), int(get(vid, "boot")), int(get(vid, "round"))
    if phase == "state":
        svcs = ["Spooler", "W32Time", "MyApp", "sppsvc"]
        if b.get("WBREAK") == "1" and boot > 0:
            svcs.remove("MyApp")
        svcs = [s for s in svcs if s not in ignore.split(",")]
        return ["AU_BOOT|202610%02d030000" % (boot + 1), "AU_OS|Microsoft Windows 11 Pro 10.0.26100",
                "AU_RUNNING|" + ",".join(svcs), "AU_PENDING|" + get(vid, "pending"), "AU_DONE"]
    if phase == "start":
        return ["AU_DONE"]
    if phase == "reboot":
        put(vid, "boot", boot + 1); put(vid, "pending", 0)
        if b.get("WNOBOOT") == "1":
            open("%s/beh/%s.noagent" % (MOCK, vid), "w").close()
        return ["AU_DONE"]
    if b.get("WERR"):
        return ["AU_WINERR|" + b["WERR"].replace("_", " "), "AU_WIN|0|0|0|0", "AU_DONE"]
    n = int(b.get("WUPD", "0")) if rnd == 0 else int(b.get("WUPD2", "0")) if rnd == 1 else 0
    ups = [("KB%d" % (5044280 + rnd * 10 + i), "2026-10 Update %d for Windows 11 (KB%d)" % (i, 5044280 + rnd * 10 + i)) for i in range(n)]
    out = ["AU_UPD|%s|%s" % u for u in ups]
    if phase == "check" or n == 0:
        return out + ["AU_WIN|%d|0|0|%s" % (n, get(vid, "pending")), "AU_DONE"]
    fail = int(b.get("WFAIL", "0")) if rnd == 0 else 0
    out += ["AU_UPDFAIL|%s|4" % t for _, t in ups[n - fail:]]
    rb = 1 if b.get("WREBOOT") == "1" else 0
    put(vid, "round", rnd + 1)
    if rb:
        put(vid, "pending", 1)
    return out + ["AU_WIN|%d|%d|%d|%d" % (n - fail, fail, rb, rb), "AU_DONE"]


if sys.argv[1] == "exec":
    args = sys.argv[2:]
    vid = args[0]
    script = base64.b64decode(args[args.index("-EncodedCommand") + 1]).decode("utf-16-le")
    pid = int(get(vid, "pid")) + 1
    put(vid, "pid", pid)
    if "$Phase='install'" in script and beh(vid).get("WHANG") == "1":
        put(vid, "p%d" % pid, "HANG")
    else:
        put(vid, "p%d" % pid, json.dumps("\r\n".join(run(vid, script)) + "\r\n"))
    print(json.dumps({"pid": pid}))
else:  # status <id> <pid>
    vid, pid = sys.argv[2], sys.argv[3]
    data = get(vid, "p" + pid, "")
    if data == "HANG":
        print(json.dumps({"exited": 0}))
    else:
        print(json.dumps({"exited": 1, "exitcode": 0, "out-data": json.loads(data)}))
