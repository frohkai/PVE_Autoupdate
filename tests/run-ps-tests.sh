#!/usr/bin/env bash
# Tests the PowerShell part (WIN_PS) that runs inside Windows VMs - against a fake
# Windows Update API, with real PowerShell (pwsh, Linux is fine):
#
#   docker run --rm -v "$PWD:/src:ro" mcr.microsoft.com/powershell bash /src/tests/run-ps-tests.sh
#
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
sed -n "/^read -r -d '' WIN_PS <<'PS_EOF'/,/^PS_EOF/p" "$SRC/pve-autoupdate.sh" | sed '1d;$d' > "$W/win.ps1"

PASS=0; FAILED=0
check(){ if grep -qE -- "$2" "$3"; then PASS=$((PASS+1)); echo "  ok   $1"; else FAILED=$((FAILED+1)); echo "  FAIL $1"; cat "$3"; fi; }
run(){ # name phase [env]
  { cat "$SRC/tests/wu-mock.ps1"; printf "%s\$Phase='%s'; \$Ignore='sppsvc,BITS'; \$Names=''\n" "${3:-}" "$2"; cat "$W/win.ps1"; } > "$W/$1.ps1"
  pwsh -NoProfile -NonInteractive -File "$W/$1.ps1" > "$W/$1.out" 2>&1
}

echo "== PowerShell syntax"
pwsh -NoProfile -Command "\$e=\$null; \$t=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$W/win.ps1',[ref]\$t,[ref]\$e); if (\$e.Count) { \$e; exit 1 }" > "$W/parse.out" 2>&1
if [ -s "$W/parse.out" ]; then FAILED=$((FAILED+1)); echo "  FAIL parses"; cat "$W/parse.out"; else PASS=$((PASS+1)); echo "  ok   parses"; fi
echo "== check"
run check check
check "lists updates with KB"            '^AU_UPD\|KB5044284\|2026-10 Cumulative' "$W/check.out"
check "pipe in title is removed"          '^AU_UPD\|KB2267602\|Defender +Security Intelligence$' "$W/check.out"
check "update without KB -> '-'"          '^AU_UPD\|-\|Store app without KB' "$W/check.out"
check "no feature upgrade"                '^AU_WIN\|4\|' "$W/check.out"
check "nothing installed"                 '^AU_DONE$' "$W/check.out"
if grep -qE "25H2|Needs a click" "$W/check.out"; then FAILED=$((FAILED+1)); echo "  FAIL filtered updates show up"; else PASS=$((PASS+1)); echo "  ok   upgrade + interactive update filtered"; fi

echo "== install"
run install install
check "3 ok, 1 failed, reboot"            '^AU_WIN\|3\|1\|1\|0$' "$W/install.out"
check "failed update named"               '^AU_UPDFAIL\|Broken .NET update\|4$' "$W/install.out"

echo "== state"
run state state
check "boot time"                         '^AU_BOOT\|20261020030000$' "$W/state.out"
check "ignored services left out"         '^AU_RUNNING\|Spooler,W32Time$' "$W/state.out"

echo "== Windows Update error"
run err install "\$env:WUFAIL='1'; "
check "error reported, not fatal"         '^AU_WINERR\|.*0x8024402C' "$W/err.out"
check "still finishes"                    '^AU_DONE$' "$W/err.out"

echo
echo "passed: $PASS  failed: $FAILED"
[ "$FAILED" = 0 ]
