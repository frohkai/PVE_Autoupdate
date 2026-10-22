#!/usr/bin/env bash

# Copyright (c) 2026 Kai Frohwerk
# Author: Kai Frohwerk
# License: MIT | https://github.com/frohkai/PVE_Autoupdate/raw/main/LICENSE
# Source: https://github.com/frohkai/PVE_Autoupdate
#
# pve-autoupdate - unattended updates for Proxmox VE (single node or cluster)
#
#   - LXC containers (apt, apk, dnf/yum, zypper, pacman)
#   - Linux VMs with QEMU guest agent (optional)
#   - apps inside the guests: Docker Compose stacks, AdGuard Home, Forgejo,
#     Uptime Kuma, Beszel - plus your own services from services.d/
#   - the Proxmox nodes themselves (optional, rolling reboots in a cluster)
#
#   Safety net per guest: snapshot -> update -> health check -> rollback on failure.
#   Mail report: never / on problems / on changes / always (postfix or own SMTP).
#
# Install (as root on one node):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/frohkai/PVE_Autoupdate/main/pve-autoupdate.sh)"

set -uo pipefail

VERSION="2.0.0"
AUTHOR="Kai Frohwerk"
REPO="frohkai/PVE_Autoupdate"
WEBSITE="https://kaimazon.de"
DONATE_URL="https://liberapay.com/__LIBERAPAY_USER__/donate"
LOGO_URL="__LOGO_URL__"     # hosted PNG for the mail header (mail clients block SVG/inline images)
REPO_URL="https://github.com/$REPO"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/pve-autoupdate.sh"

BIN=/usr/local/sbin/pve-autoupdate
CONF_DIR=/etc/pve-autoupdate
CONF="$CONF_DIR/config"
SVC_DIR="$CONF_DIR/services.d"
STATE=/var/lib/pve-autoupdate
LOGF=/var/log/pve-autoupdate.log
LOCKF=/run/pve-autoupdate.lock
UNIT=pve-autoupdate
SNAP=autoupdate

# ---------------------------------------------------------------- defaults
UI_LANG="${PVE_AUTOUPDATE_LANG:-en}"   # en | de
GUESTS=all                 # all | list of IDs ("101 105") | empty = no guests
EXCLUDE=""                 # with GUESTS=all: excluded IDs
INCLUDE_VMS=0              # with GUESTS=all: VMs too (guest agent required)
UPDATE_HOSTS=1             # update the Proxmox nodes themselves
UPDATE_SERVICES=1          # Docker stacks + detected apps
SNAPSHOT=optional          # required | optional | off
REBOOT_GUESTS=1            # reboot guests when an update needs it
REBOOT_HOSTS=0             # reboot nodes (one after another in a cluster)
SCHEDULE="Mon *-*-* 03:00:00"
UPDATE_WINDOW=""           # "02:00-05:00": updates and reboots only inside this window (may cross midnight); empty = no limit
NOTIFY=errors              # never | errors | changes | always
MAIL_TO=""
MAIL_FROM=""
MAIL_TRANSPORT=system      # system (postfix/sendmail) | smtp
SMTP_HOST=""
SMTP_PORT=587
SMTP_SECURITY=starttls     # starttls | ssl | none
SMTP_USER=""
SMTP_PASS=""
TITLE=""
SETTLE=20                  # seconds to wait before the health check
UPDATE_WINDOWS=1           # Windows VMs: Windows Update via guest agent (needs a reboot to finish)
WIN_UPDATE_TIMEOUT=180     # minutes one Windows Update round may take
WIN_REBOOT_TIMEOUT=60      # minutes a Windows VM may take to come back after the reboot
# automatic services that stop on their own - never count as "failed" after an update
WIN_IGNORE_SERVICES="sppsvc,gupdate,gupdatem,edgeupdate,edgeupdatem,MapsBroker,RemoteRegistry,TrustedInstaller,wuauserv,UsoSvc,BITS,WaaSMedicSvc,DoSvc,InstallService,TabletInputService,CDPSvc,ShellHWDetection,sedsvc,WbioSrvc,tiledatamodelsvc,MicrosoftEdgeElevationService,clr_optimization_v4.0.30319_32,clr_optimization_v4.0.30319_64"

CONF_VARS="UI_LANG GUESTS EXCLUDE INCLUDE_VMS UPDATE_HOSTS UPDATE_SERVICES SNAPSHOT REBOOT_GUESTS
REBOOT_HOSTS SCHEDULE UPDATE_WINDOW NOTIFY MAIL_TO MAIL_FROM MAIL_TRANSPORT SMTP_HOST SMTP_PORT
SMTP_SECURITY SMTP_USER SMTP_PASS TITLE SETTLE UPDATE_WINDOWS WIN_UPDATE_TIMEOUT WIN_REBOOT_TIMEOUT
WIN_IGNORE_SERVICES"

# ---------------------------------------------------------------- language
# L "english" "deutsch" - prints the text in the chosen language
L(){ if [ "$UI_LANG" = de ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# ---------------------------------------------------------------- look & feel
INTERACTIVE=0; { [ -t 1 ] && [ -t 2 ]; } && INTERACTIVE=1
# Theme: kaimazon.de (amber #F2A93B on ink #14181F). PVE_AUTOUPDATE_THEME=classic or
# NO_COLOR=1 switches back to plain terminal colours and the default whiptail look.
THEME="${PVE_AUTOUPDATE_THEME:-kaimazon}"; [ -n "${NO_COLOR:-}" ] && THEME=classic
color(){
  YW=$'\033[33m'; YWB=$'\033[93m'; BL=$'\033[36m'; RD=$'\033[01;31m'
  GN=$'\033[1;92m'; DGN=$'\033[32m'; CL=$'\033[m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  AC="$YWB"; ACD="$YW"; INK=""; MUT="$DIM"
  if [ "$THEME" != classic ]; then  # truecolor works in the PVE web shell (xterm.js), SSH clients and most terminals
    AC=$'\033[38;2;242;169;59m'; ACD=$'\033[38;2;217;143;31m'; INK=$'\033[38;2;238;241;246m'
    MUT=$'\033[38;2;108;116;132m'; BL=$'\033[38;2;168;176;190m'; YW="$AC"
  fi
  TAB="  "; CM="${TAB}✔️${TAB}"; CROSS="${TAB}✖️${TAB}"; INFO="${TAB}💡${TAB}"
}
YW=""; YWB=""; BL=""; RD=""; GN=""; DGN=""; CL=""; BOLD=""; DIM=""; AC=""; ACD=""; INK=""; MUT=""
TAB="  "; CM="  [OK] "; CROSS="  [!!] "; INFO="  [--] "
[ "$INTERACTIVE" = 1 ] && color

# whiptail/newt only knows the 16 base colours: closest match to the site is
# black surface, yellow (amber) accents, black-on-yellow selection.
if [ "$THEME" != classic ] && [ -z "${NEWT_COLORS:-}" ]; then
  export NEWT_COLORS='
root=white,black
border=yellow,black
window=white,black
shadow=black,black
title=yellow,black
button=black,yellow
actbutton=black,yellow
compactbutton=lightgray,black
checkbox=lightgray,black
actcheckbox=black,yellow
entry=white,black
disentry=gray,black
label=lightgray,black
listbox=lightgray,black
actlistbox=black,yellow
sellistbox=yellow,black
actsellistbox=black,yellow
textbox=lightgray,black
acttextbox=black,yellow
emptyscale=,gray
fullscale=,yellow
helpline=black,yellow
roottext=yellow,black'
fi

has_donate(){ [[ "$DONATE_URL" == http* && "$DONATE_URL" != *__* ]]; }
has_repo(){ [[ "$REPO" != *__* ]]; }
has_logo(){ [[ "$LOGO_URL" == http* && "$LOGO_URL" != *__* ]]; }
BACKTITLE=">_ pve-autoupdate $VERSION  ·  by $AUTHOR  ·  ${WEBSITE#https://}"
DONATE_TXT(){ L "Like it? Support me on Liberapay:" "Gefällt's dir? Unterstütz mich auf Liberapay:"; }

header_info(){
  [ "$INTERACTIVE" = 1 ] || return 0
  clear
  printf '%s' "$AC$BOLD"
  cat <<"EOF"

  ██████╗ ██╗   ██╗███████╗
  ██╔══██╗██║   ██║██╔════╝
  ██████╔╝██║   ██║█████╗
  ██╔═══╝ ╚██╗ ██╔╝██╔══╝
  ██║      ╚████╔╝ ███████╗
  ╚═╝       ╚═══╝  ╚══════╝
EOF
  printf '%s' "$CL"
  echo -e "  ${INK}${BOLD}A U T O U P D A T E${CL}   ${MUT}v${VERSION}${CL}"
  echo -e "  ${ACD}━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${AC}${BOLD}>_${CL} ${INK}$(L "unattended updates for Proxmox VE" "automatische Updates für Proxmox VE")${CL}"
  echo -e "  ${MUT}by${CL} ${INK}${BOLD}${AUTHOR}${CL} ${MUT}·${CL} ${AC}${WEBSITE#https://}${CL}"
  has_donate && echo -e "  ${MUT}♥ $(DONATE_TXT)${CL} ${AC}${DONATE_URL}${CL}"
  echo
}

SPINNER_PID=""
spinner(){
  local c=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0
  while :; do printf "\r\033[2K%s %b" "${TAB}${AC}${c[i++ % 10]}${CL}" "${INK}$1${CL}"; sleep 0.1; done
}
stop_spinner(){
  if [ -n "$SPINNER_PID" ]; then
    kill "$SPINNER_PID" 2>/dev/null; wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""; printf "\r\033[2K"
  fi
  return 0
}
msg_info(){
  if [ "$INTERACTIVE" = 1 ]; then
    stop_spinner
    spinner "$1" 9>&- &        # never pass the lock (fd 9) to the spinner
    SPINNER_PID=$!
  fi
  return 0
}
msg_ok(){    stop_spinner; echo -e "${CM}${GN}$1${CL}"; }
msg_warn(){  stop_spinner; echo -e "${INFO}${AC}$1${CL}"; }
msg_error(){ stop_spinner; echo -e "${CROSS}${RD}$1${CL}" >&2; }
trap 'stop_spinner' EXIT
trap 'stop_spinner; echo; exit 130' INT TERM

pause(){ [ "$INTERACTIVE" = 1 ] && read -r -p "$(L "Press Enter to continue ..." "Weiter mit Enter ...") " _; return 0; }
confirm(){ # question -> 0 on yes
  local a; read -r -p "$1 [y/N]: " a
  [[ "$a" =~ ^([yYjJ]|yes|ja)$ ]]
}

# ---------------------------------------------------------------- helpers
log(){
  local m; m="[$(date '+%F %T')] $*"
  echo "$m" >> "$LOGF" 2>/dev/null
  [ "$INTERACTIVE" = 1 ] || echo "$m" >&2
  ev log msg="$*"
}
die(){ msg_error "$(L "ERROR" "FEHLER"): $*"; exit 1; }
need_root(){ [ "$(id -u)" = 0 ] || die "$(L "please run as root" "bitte als root ausführen")"; }
need_pve(){
  { command -v pvesh >/dev/null && [ -d /etc/pve ]; } || die "$(L "no Proxmox VE found (pvesh or /etc/pve missing)" "kein Proxmox VE gefunden (pvesh oder /etc/pve fehlt)")"
  local v; v=$(pveversion 2>/dev/null | grep -oE 'pve-manager/[0-9]+' | cut -d/ -f2)
  if [ -n "$v" ] && [ "$v" -lt 7 ]; then die "$(L "Proxmox VE 7 or newer required" "Proxmox VE 7 oder neuer nötig")"; fi
  return 0
}
need_whiptail(){ command -v whiptail >/dev/null || die "$(L "whiptail missing: apt install whiptail" "whiptail fehlt: apt install whiptail")"; }
load_config(){
  if [ -r "$CONF" ]; then . "$CONF"; fi
  [ -n "${PVE_AUTOUPDATE_LANG:-}" ] && UI_LANG="$PVE_AUTOUPDATE_LANG"
  [ "$UI_LANG" = de ] || UI_LANG=en
  [ -n "$TITLE" ] || TITLE="$(hostname -s 2>/dev/null || hostname)"
  return 0
}
he(){ printf '%s' "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
in_list(){ case " $2 " in *" $1 "*) return 0;; esac; return 1; }
yesno_txt(){ if [ "$1" = 1 ]; then L yes ja; else L no nein; fi; }
pkgs_txt(){ if [ "$1" = 1 ]; then L "1 package" "1 Paket"; else L "$1 packages" "$1 Pakete"; fi; }
stamp(){ if [ "$UI_LANG" = de ]; then date '+%d.%m.%Y  %H:%M'; else date '+%Y-%m-%d  %H:%M'; fi; }

write_config(){
  local v tmp um
  um=$(umask); umask 077; mkdir -p "$CONF_DIR" "$SVC_DIR"
  tmp="$CONF.tmp.$$"
  {
    echo "# pve-autoupdate $VERSION - configuration (changed $(date '+%F %T'))"
    echo "# Edit with: pve-autoupdate setup  (or here by hand, then: pve-autoupdate setup --apply)"
    for v in $CONF_VARS; do printf '%s=%q\n' "$v" "${!v}"; done
  } > "$tmp" && mv "$tmp" "$CONF" && chmod 600 "$CONF"
  local rc=$?; umask "$um"; return "$rc"
}

# ---------------------------------------------------------------- cluster / nodes
declare -A NODE_IP=() NODE_ONLINE=()
NODES=""; SELF=""; CLUSTER_NAME=""

load_nodes(){
  local out t a b c d
  out=$(pvesh get /cluster/status --output-format json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
for r in data:
    if r.get("type") == "cluster":
        print("C|%s||||" % r.get("name", ""))
    elif r.get("type") == "node":
        print("N|%s|%s|%s|%s" % (r.get("name", ""), r.get("ip", ""), r.get("online", 0), r.get("local", 0)))
')
  NODES=""; CLUSTER_NAME=""; SELF=""
  while IFS='|' read -r t a b c d; do
    case "$t" in
      C) CLUSTER_NAME="$a" ;;
      N) NODES="$NODES $a"; NODE_IP[$a]="$b"; NODE_ONLINE[$a]="$c"; [ "$d" = 1 ] && SELF="$a" ;;
    esac
  done <<< "$out"
  [ -n "$SELF" ] || SELF="$(hostname -s 2>/dev/null || hostname)"
  if [ -z "${NODES// /}" ]; then NODES="$SELF"; NODE_ONLINE[$SELF]=1; fi
  NODES=$(printf '%s\n' $NODES | sort -u | tr '\n' ' ')
  NODES="${NODES% }"
}

# Run a command on a node. Other nodes are reached via their cluster IP
# (not their name - that does not resolve everywhere).
node_run(){
  local node="$1" cmd="$2"
  # 9>&- : do not pass the lock (fd 9) on to child processes
  if [ "$node" = "$SELF" ]; then
    bash -c "$cmd" </dev/null 9>&-
  else
    ssh -n 9>&- -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=6 \
        -o StrictHostKeyChecking=accept-new -o HostKeyAlias="$node" \
        "root@${NODE_IP[$node]:-$node}" "$cmd"
  fi
}

# id|type|name|node|status|template - live, so HA migrations are taken into account
list_guests(){
  pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
for r in sorted(data, key=lambda r: int(r.get("vmid", 0))):
    name = (r.get("name") or "").replace("|", "/")
    print("%s|%s|%s|%s|%s|%s" % (r.get("vmid"), r.get("type"), name, r.get("node", ""),
                                  r.get("status", ""), r.get("template", 0) or 0))
'
}

guest_field(){ # id fieldnumber
  list_guests | awk -F'|' -v id="$1" -v f="$2" '$1==id{print $f; exit}'
}

is_selected(){ # id type
  in_list "$1" "$EXCLUDE" && return 1
  if [ "$GUESTS" = all ]; then
    [ "$2" = lxc ] || [ "$INCLUDE_VMS" = 1 ]
  else
    in_list "$1" "$GUESTS"
  fi
}

# ============================================================================
#  Runner - runs INSIDE the guest or on the node. Plain POSIX sh (Alpine too).
#  Output: machine readable lines AU_PKG / AU_SVC / AU_REBOOT / AU_HEALTH.
# ============================================================================
read -r -d '' RUNNER_HEAD <<'RUNNER_EOF'
#!/bin/sh
MODE="${1:-dryrun}"; SERVICES="${2:-1}"; ROLE="${3:-guest}"; SETTLE="${4:-20}"; LNG="${5:-en}"
PATH="${PATH:+$PATH:}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; export PATH
DEBIAN_FRONTEND=noninteractive; export DEBIAN_FRONTEND
m(){ if [ "$LNG" = de ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
W="/tmp/.pve-autoupdate.$$"; rm -rf "$W"; mkdir -p "$W" || { echo "AU_HEALTH|fail|$(m 'no /tmp' 'kein /tmp')"; echo AU_DONE; exit 0; }
LOG="$W/log"; : > "$LOG"
HEALTH=ok; HNOTE=""

have(){ command -v "$1" >/dev/null 2>&1; }
# lines of file 1 that are not in file 2 (awk instead of grep -f: BusyBox treats empty pattern files differently)
only_in(){ awk -v f="$2" 'BEGIN{while((getline l < f)>0) s[l]=1} !($0 in s)' "$1"; }
fail_health(){ HEALTH=fail; HNOTE="${HNOTE:+$HNOTE; }$1"; }
svc(){ echo "AU_SVC|$1|$2|$3|$4|$5"; [ "$4" = WARN ] && echo "$1" >> "$W/warn"; return 0; }
is_systemd(){ have systemctl && [ -d /run/systemd/system ]; }
unit_exists(){ is_systemd && systemctl list-unit-files "$1.service" --no-legend 2>/dev/null | grep -q .; }
wait_active(){ _i=0; while [ $_i -lt 20 ]; do systemctl is-active --quiet "$1" && return 0; _i=$((_i+1)); sleep 3; done; return 1; }
unit_ok(){ for _u in "$@"; do if unit_exists "$_u"; then wait_active "$_u"; return $?; fi; done; return 0; }
restart_unit(){ for _u in "$@"; do if unit_exists "$_u"; then systemctl restart "$_u"; return $?; fi; done; return 0; }
failed_units(){
  if is_systemd; then systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}'
  elif have rc-status; then rc-status --crashed 2>/dev/null; fi | sort
}

# ---------------------------------------------------------------- state before
failed_units > "$W/failed.before"
DOCKER=0
if [ "$SERVICES" = 1 ] && have docker && docker info >/dev/null 2>&1; then
  DOCKER=1
  docker ps --format '{{.Names}}' 2>/dev/null | sort > "$W/docker.before"
  docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null | sort > "$W/unhealthy.before"
fi

# ---------------------------------------------------------------- packages
PM=none; PKGS=0; REF=0; UPG=0; PMREBOOT=no
for _p in apt-get apk dnf yum zypper pacman; do have "$_p" && { PM=$_p; break; }; done
case "$PM" in
  apt-get)
    apt-get -o DPkg::Lock::Timeout=600 update -qq >>"$LOG" 2>&1 || REF=$?
    PKGS=$(apt-get -s -o Dpkg::Options::=--force-confold dist-upgrade 2>>"$LOG" | grep -c '^Inst ')
    if [ "$MODE" = live ] && [ "$PKGS" -gt 0 ]; then
      apt-get -y -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold dist-upgrade >>"$LOG" 2>&1 || UPG=$?
      if [ "$UPG" = 0 ]; then apt-get -y --purge autoremove >>"$LOG" 2>&1; apt-get clean >/dev/null 2>&1; fi
    fi ;;
  apk)
    apk update -q >>"$LOG" 2>&1 || REF=$?
    PKGS=$(apk version -l '<' 2>/dev/null | grep -c '<')
    if [ "$MODE" = live ] && [ "$PKGS" -gt 0 ]; then apk upgrade --no-progress >>"$LOG" 2>&1 || UPG=$?; fi ;;
  dnf|yum)
    "$PM" -q -y makecache >>"$LOG" 2>&1 || REF=$?
    PKGS=$("$PM" -q check-update 2>/dev/null | grep -cE '^[^[:space:]]+\.[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+')
    if [ "$MODE" = live ] && [ "$PKGS" -gt 0 ]; then "$PM" -y upgrade >>"$LOG" 2>&1 || UPG=$?; fi ;;
  zypper)
    zypper -n -q refresh >>"$LOG" 2>&1 || REF=$?
    PKGS=$(zypper -n -q list-updates 2>/dev/null | grep -c '^v ')
    if [ "$MODE" = live ] && [ "$PKGS" -gt 0 ]; then
      zypper -n update -y --auto-agree-with-licenses >>"$LOG" 2>&1 || UPG=$?
      [ "$UPG" = 102 ] && PMREBOOT=yes
      case "$UPG" in 100|101|102|103|106) UPG=0 ;; esac
    fi ;;
  pacman)
    pacman -Sy --noconfirm >>"$LOG" 2>&1 || REF=$?
    PKGS=$(pacman -Qu 2>/dev/null | wc -l)
    if [ "$MODE" = live ] && [ "$PKGS" -gt 0 ]; then pacman -Su --noconfirm >>"$LOG" 2>&1 || UPG=$?; fi ;;
esac
PKGS=$((PKGS+0))
[ "$UPG" = 0 ] || fail_health "$(m "package upgrade failed ($PM, rc=$UPG)" "Paket-Upgrade fehlgeschlagen ($PM, rc=$UPG)")"

# ---------------------------------------------------------------- Docker Compose
dc(){ if docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi; }
if [ "$DOCKER" = 1 ]; then
  if docker compose version >/dev/null 2>&1 || have docker-compose; then
    docker ps -a --format '{{.Label "com.docker.compose.project"}}|{{.Label "com.docker.compose.project.working_dir"}}|{{.Label "com.docker.compose.project.config_files"}}' 2>/dev/null \
      | grep -v '^|' | sort -u > "$W/projects"
    while IFS='|' read -r proj wd files; do
      [ -n "$proj" ] || continue
      set -- -p "$proj"; found=0
      _ifs=$IFS; IFS=','
      for f in $files; do [ -f "$f" ] && { set -- "$@" -f "$f"; found=1; }; done
      IFS=$_ifs
      if [ "$found" = 0 ]; then svc "Docker: $proj" - - WARN "$(m 'compose file not found' 'Compose-Datei nicht gefunden')"; continue; fi
      if [ "$MODE" != live ]; then svc "Docker: $proj" - - INFO "$(m 'compose stack detected' 'Compose-Stack erkannt')"; continue; fi
      ( cd "$wd" 2>/dev/null || cd /; dc "$@" ps -q ) </dev/null 2>/dev/null | sort > "$W/ids.before"
      ( cd "$wd" 2>/dev/null || cd /; dc "$@" pull -q --ignore-pull-failures ) </dev/null >>"$LOG" 2>&1
      if ! ( cd "$wd" 2>/dev/null || cd /; dc "$@" up -d ) </dev/null >>"$LOG" 2>&1; then
        svc "Docker: $proj" - - ERROR "$(m 'docker compose up failed' 'docker compose up fehlgeschlagen')"
        fail_health "Docker $proj: $(m 'up -d failed' 'up -d fehlgeschlagen')"; continue
      fi
      ( cd "$wd" 2>/dev/null || cd /; dc "$@" ps -q ) </dev/null 2>/dev/null | sort > "$W/ids.after"
      n=$(only_in "$W/ids.after" "$W/ids.before" | grep -c .)
      if [ "$n" -gt 0 ]; then svc "Docker: $proj" - - NEW "$(m "$n container(s) recreated" "$n Container neu erstellt")"
      else svc "Docker: $proj" - - CURRENT -; fi
    done < "$W/projects"
    [ "$MODE" = live ] && docker image prune -f >/dev/null 2>&1
  fi
  solo=$(docker ps -a --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | grep -c '^$')
  [ "$solo" -gt 0 ] && svc "Docker" - - INFO "$(m "$solo container(s) without compose - not updated" "$solo Container ohne Compose - werden nicht aktualisiert")"
fi

# ---------------------------------------------------------------- apps
run_recipe(){ # display_name key
  rn=$1; rk=$2
  rb=$(${rk}_ver 2>/dev/null </dev/null | tail -n 1); rb=${rb:--}
  if [ "$MODE" != live ]; then svc "$rn" "$rb" - INFO "$(m detected erkannt)"; return 0; fi
  ro=$(${rk}_upd 2>&1 </dev/null); rrc=$?
  printf '%s\n' "$ro" | tail -n 5 | sed "s|^|[$rn] |" >> "$LOG"
  ra=$(${rk}_ver 2>/dev/null </dev/null | tail -n 1); ra=${ra:--}
  echo "$rn|$rk" >> "$W/recipes"
  if [ "$rrc" != 0 ]; then svc "$rn" "$rb" "$ra" WARN "$(m "update command reported an error (rc=$rrc)" "Update-Befehl meldete Fehler (rc=$rrc)")"
  elif [ "$rb" != "$ra" ]; then svc "$rn" "$rb" "$ra" NEW -
  else svc "$rn" "$rb" "$ra" CURRENT -; fi
}

adguard_ver(){ /opt/AdGuardHome/AdGuardHome --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1; }
adguard_upd(){ /opt/AdGuardHome/AdGuardHome --update; }
adguard_hlt(){ unit_ok AdGuardHome; }

beszelhub_ver(){ /opt/beszel/beszel --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1; }
beszelhub_upd(){ /opt/beszel/beszel update && restart_unit beszel-hub beszel; }
beszelhub_hlt(){ unit_ok beszel-hub beszel; }

beszelagent_ver(){ /opt/beszel-agent/beszel-agent --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1; }
beszelagent_upd(){ /opt/beszel-agent/beszel-agent update && restart_unit beszel-agent; }
beszelagent_hlt(){ unit_ok beszel-agent; }

forgejo_bin(){ for _b in /usr/local/bin/forgejo /usr/bin/forgejo /opt/forgejo/forgejo; do [ -x "$_b" ] && { echo "$_b"; return 0; }; done; return 1; }
forgejo_ver(){ "$(forgejo_bin)" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1; }
forgejo_upd(){ (
  set -e
  fb=$(forgejo_bin)
  case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) echo "architecture $(uname -m) not supported"; exit 1 ;; esac
  v=$(curl -fsS --max-time 30 "https://codeberg.org/api/v1/repos/forgejo/forgejo/releases?limit=10&pre-release=false&draft=false" \
      | grep -oE '"tag_name":"v?[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
  [ -n "$v" ] || { echo "no version found"; exit 1; }
  cur=$(forgejo_ver)
  [ "$(printf '%s\n%s\n' "$cur" "$v" | sort -V | tail -n 1)" = "$cur" ] && { echo "up to date ($cur)"; exit 0; }
  base="https://codeberg.org/forgejo/forgejo/releases/download/v$v"
  t=$(mktemp -d)
  curl -fsSL --max-time 900 -o "$t/forgejo" "$base/forgejo-$v-linux-$arch"
  # checksum: mandatory for an unattended update - otherwise a half download would be the binary
  if curl -fsSL --max-time 60 -o "$t/sha" "$base/forgejo-$v-linux-$arch.sha256"; then
    exp=$(grep -oE '^[0-9a-f]{64}' "$t/sha" | head -n 1); got=$(sha256sum "$t/forgejo" | cut -d' ' -f1)
    [ "$exp" = "$got" ] || { echo "checksum mismatch"; rm -rf "$t"; exit 1; }
  fi
  chmod 755 "$t/forgejo"
  systemctl stop forgejo
  cp -a "$fb" "$fb.bak"
  mv "$t/forgejo" "$fb"
  rm -rf "$t"
  systemctl start forgejo
  echo "updated to $v"
) }
forgejo_hlt(){ unit_ok forgejo; }

kuma_ver(){ grep -m1 '"version"' /opt/uptime-kuma/package.json 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }
kuma_upd(){ (
  set -e
  cd /opt/uptime-kuma
  git fetch --all --tags --quiet
  cur=$(kuma_ver); major=${cur%%.*}
  # within the major version only - 1.x -> 2.x migrates the database for hours
  v=$(git tag -l | grep -E "^${major}\.[0-9]+\.[0-9]+$" | sort -V | tail -n 1)
  [ -n "$v" ] && [ "$v" != "$cur" ] || { echo "up to date ($cur)"; exit 0; }
  systemctl stop uptime-kuma
  git checkout "$v" --force --quiet
  npm ci --omit=dev --no-audit --no-fund >/dev/null 2>&1
  npm run download-dist >/dev/null 2>&1
  systemctl start uptime-kuma
  echo "updated to $v"
) }
# Kuma already answers on its port during a database migration -
# so first wait for silence in the log ("DON'T STOP"), then check.
kuma_hlt(){
  unit_exists uptime-kuma || return 0
  systemctl is-active --quiet uptime-kuma || return 1
  _i=0
  while [ $_i -lt 160 ]; do
    _i=$((_i+1))
    if journalctl -u uptime-kuma --since "-45s" --no-pager 2>/dev/null | grep -q "DON'T STOP"; then sleep 15; continue; fi
    if have curl; then curl -s -o /dev/null --max-time 5 http://127.0.0.1:3001/ && return 0
    else wait_active uptime-kuma && return 0; fi
    sleep 5
  done
  return 1
}

if [ "$SERVICES" = 1 ]; then
  [ -x /opt/AdGuardHome/AdGuardHome ] && run_recipe "AdGuard Home" adguard
  [ -x /opt/beszel/beszel ] && run_recipe "Beszel Hub" beszelhub
  [ -x /opt/beszel-agent/beszel-agent ] && run_recipe "Beszel Agent" beszelagent
  forgejo_bin >/dev/null && unit_exists forgejo && run_recipe "Forgejo" forgejo
  [ -d /opt/uptime-kuma/.git ] && have git && have npm && run_recipe "Uptime Kuma" kuma
fi

# ---------------------------------------------------------------- own services
retry_sh(){ _i=0; while [ $_i -lt 6 ]; do echo "$1" | base64 -d | sh >/dev/null 2>&1 && return 0; _i=$((_i+1)); sleep 10; done; return 1; }
CN=0
custom(){ # name ver_b64 upd_b64 hlt_b64
  [ "$SERVICES" = 1 ] || return 0
  CN=$((CN+1))
  eval "c${CN}_ver(){ [ -n '$2' ] && echo '$2' | base64 -d | sh; }"
  eval "c${CN}_upd(){ echo '$3' | base64 -d | sh; }"
  eval "c${CN}_hlt(){ [ -z '$4' ] && return 0; retry_sh '$4'; }"
  run_recipe "$1" "c${CN}"
}
RUNNER_EOF

read -r -d '' RUNNER_TAIL <<'RUNNER_EOF'
# ---------------------------------------------------------------- health check
if [ "$MODE" = live ]; then
  sleep "$SETTLE"
  if [ -f "$W/recipes" ]; then
    while IFS='|' read -r rn rk; do
      ${rk}_hlt </dev/null >>"$LOG" 2>&1 || fail_health "$rn $(m 'does not respond' 'antwortet nicht')"
    done < "$W/recipes"
  fi
  if [ "$DOCKER" = 1 ]; then
    _i=0
    while [ $_i -lt 12 ] && docker ps --filter health=starting -q 2>/dev/null | grep -q .; do _i=$((_i+1)); sleep 10; done
    docker ps --format '{{.Names}}' 2>/dev/null | sort > "$W/docker.after"
    miss=$(only_in "$W/docker.before" "$W/docker.after" | tr '\n' ' ' | sed 's/ *$//')
    [ -n "$miss" ] && fail_health "$(m 'Docker containers no longer running:' 'Docker-Container laufen nicht mehr:') $miss"
    docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null | sort > "$W/unhealthy.after"
    unh=$(only_in "$W/unhealthy.after" "$W/unhealthy.before" | tr '\n' ' ' | sed 's/ *$//')
    [ -n "$unh" ] && fail_health "$(m 'Docker containers unhealthy:' 'Docker-Container unhealthy:') $unh"
  fi
  failed_units > "$W/failed.after"
  newf=$(only_in "$W/failed.after" "$W/failed.before" | tr '\n' ' ' | sed 's/ *$//')
  [ -n "$newf" ] && fail_health "$(m 'newly failed services:' 'neu ausgefallene Dienste:') $newf"
fi

# ---------------------------------------------------------------- reboot needed?
REBOOT=$PMREBOOT
[ -f /var/run/reboot-required ] && REBOOT=yes
case "$PM" in dnf|yum) if have needs-restarting && ! needs-restarting -r >/dev/null 2>&1; then REBOOT=yes; fi ;; esac
if [ "$ROLE" = host ]; then
  _run=$(uname -r)
  _new=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's#.*/vmlinuz-##' | sort -V | tail -n 1)
  [ -n "$_new" ] && [ "$_run" != "$_new" ] && REBOOT=yes
fi

echo "AU_PKG|$PM|$PKGS|$REF|$UPG"
echo "AU_REBOOT|$REBOOT"
echo "AU_HEALTH|$HEALTH|$HNOTE"
if [ "$HEALTH" != ok ] || [ "$REF" != 0 ] || [ -s "$W/warn" ]; then
  echo AU_LOG_BEGIN; tail -n 30 "$LOG"; echo AU_LOG_END
fi
echo AU_DONE
rm -rf "$W"
exit 0
RUNNER_EOF

# own services from services.d/*.conf that belong to this target
custom_lines(){ # target (guest ID or node name)
  local f
  [ "$UPDATE_SERVICES" = 1 ] || return 0
  for f in "$SVC_DIR"/*.conf; do
    [ -f "$f" ] || continue
    (
      NAME=""; TARGET=""; VERSION_CMD=""; UPDATE_CMD=""; HEALTH_CMD=""
      . "$f"
      in_list "$1" "$TARGET" || exit 0
      [ -n "$UPDATE_CMD" ] || exit 0
      n=$(printf '%s' "${NAME:-$(basename "$f" .conf)}" | tr -d "'|\n")
      printf "custom '%s' '%s' '%s' '%s'\n" "$n" \
        "$(printf '%s' "$VERSION_CMD" | base64 -w0)" \
        "$(printf '%s' "$UPDATE_CMD" | base64 -w0)" \
        "$(printf '%s' "$HEALTH_CMD" | base64 -w0)"
    )
  done
}

build_runner(){ printf '%s\n' "$RUNNER_HEAD"; custom_lines "$1"; printf '%s\n' "$RUNNER_TAIL"; }

# Transfer and run the runner. Base64, because quotes, $ and newlines
# would otherwise break through ssh / pct exec / qm guest exec.
exec_runner(){ # kind(node|lxc|qemu) id node mode role
  local kind=$1 id=$2 node=$3 mode=$4 role=$5 tgt b64 inner tmp=/tmp/.pve-autoupdate-runner.sh
  if [ "$kind" = node ]; then tgt=$node; else tgt=$id; fi
  b64=$(build_runner "$tgt" | base64 -w0)
  inner="echo $b64 | base64 -d > $tmp && sh $tmp $mode $UPDATE_SERVICES $role $SETTLE $UI_LANG; rc=\$?; rm -f $tmp; exit \$rc"
  case "$kind" in
    node) node_run "$node" "timeout 7200 bash -c '$inner'" 2>&1 ;;
    lxc)  node_run "$node" "timeout 7200 pct exec $id -- sh -c '$inner'" 2>&1 ;;
    qemu) node_run "$node" "qm guest exec $id --timeout 7200 -- sh -c '$inner'" 2>&1 | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    sys.stdout.write(raw); sys.exit(1)
sys.stdout.write(d.get("out-data", "") + d.get("err-data", ""))
' ;;
  esac
}

# read the runner result -> P_* variables
parse_out(){
  local l
  P_PM=""; P_PKGS=0; P_REF=0; P_UPG=0; P_REBOOT=no; P_HEALTH=""; P_HNOTE=""; P_SVC=""; P_DONE=0
  while IFS= read -r l || [ -n "$l" ]; do    # last line may lack a newline (qm guest exec)
    case "$l" in
      AU_PKG\|*)    IFS='|' read -r _ P_PM P_PKGS P_REF P_UPG <<< "$l" ;;
      AU_SVC\|*)    P_SVC+="${l#AU_SVC|}"$'\n' ;;
      AU_REBOOT\|*) P_REBOOT="${l#AU_REBOOT|}" ;;
      AU_HEALTH\|*) IFS='|' read -r _ P_HEALTH P_HNOTE <<< "$l" ;;
      AU_DONE)      P_DONE=1 ;;
    esac
  done < "$1"
  P_LOG=$(sed -n '/^AU_LOG_BEGIN/,/^AU_LOG_END/p' "$1" | grep -v '^AU_LOG_')
  [[ "$P_PKGS" =~ ^[0-9]+$ ]] || P_PKGS=0
}

# short text for mail and table
summary(){ # mode
  local s="" name b a st note
  if [ "$P_PKGS" -gt 0 ]; then
    if [ "$1" = dryrun ]; then s="$(pkgs_txt "$P_PKGS") $(L available verfügbar)"
    else s="$(pkgs_txt "$P_PKGS") $(L updated aktualisiert)"; fi
  fi
  while IFS='|' read -r name b a st note; do
    [ -n "$name" ] || continue
    case "$st" in
      NEW)   if [ "$b" != - ]; then s+="${s:+, }$name $b -> $a"; else s+="${s:+, }$name: $note"; fi ;;
      WARN|ERROR) s+="${s:+, }$name: $note" ;;
      INFO)  if [ "$1" = dryrun ]; then
               if [ "$b" != - ]; then s+="${s:+, }$name $b"; else s+="${s:+, }$name: $note"; fi
             fi ;;
    esac
  done <<< "$P_SVC"
  echo "${s:-$(L "up to date" "aktuell")}"
}
changed_flag(){ { [ "$P_PKGS" -gt 0 ] || grep -q '|NEW|' <<< "$P_SVC"; } && echo 1 || echo 0; }
has_warn(){ [ "$P_REF" != 0 ] || grep -qE '\|(WARN|ERROR)\|' <<< "$P_SVC"; }

add_result(){ # KIND ID NAME NODE STATUS PKGS REBOOT CHANGED SUMMARY
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$@" >> "$RESULTS"
  ev result kind="$1" id="$2" name="$3" node="$4" status="$5" pkgs="$6" reboot="$7" changed="$8" summary="$9"
  [ "$INTERACTIVE" = 1 ] && show_result "$@"
  return 0
}
show_result(){
  local lbl="$1 $2 ($3)" sm="$9"
  [ "$1" = NODE ] && lbl="Node $2"
  [ "$7" = yes ] && sm="$sm  [$(L "reboot needed" "Neustart nötig")]"
  case "$5" in
    OK|TEST)  msg_ok "$lbl: $sm" ;;
    WARN|SKIP) msg_warn "$lbl: $sm" ;;
    *)        msg_error "$lbl: $sm" ;;
  esac
}
add_detail(){ { echo "--- $1"; printf '%s\n' "$2"; echo; } >> "$DETAILS"; }

# ---------------------------------------------------------------- snapshots
snap_create(){ # tool id node
  local tool=$1 id=$2 node=$3 extra=""
  [ "$tool" = qm ] && extra="--vmstate 0"
  # only delete a leftover of an earlier run if there really is one
  if node_run "$node" "$tool listsnapshot $id 2>/dev/null | grep -qw $SNAP"; then
    node_run "$node" "$tool delsnapshot $id $SNAP --force" >/dev/null 2>&1
  fi
  node_run "$node" "$tool snapshot $id $SNAP $extra --description 'pve-autoupdate $(date +%F)'" >/dev/null 2>&1
}
snap_delete(){ node_run "$3" "$1 delsnapshot $2 $SNAP" >/dev/null 2>&1; }
snap_rollback(){ # tool id node
  node_run "$3" "$1 rollback $2 $SNAP" >>"$LOGF" 2>&1 || return 1
  node_run "$3" "$1 start $2" >>"$LOGF" 2>&1
  return 0
}

# ---------------------------------------------------------------- one guest
process_guest(){ # id type name node status
  local id=$1 kind=$2 name=$3 node=$4 status=$5 tool=pct K=LXC snapped=0 note="" out st sum ostype lbl
  [ "$kind" = qemu ] && { tool=qm; K=VM; }
  lbl="$K $id ($name)"
  if [ "$status" != running ]; then add_result "$K" "$id" "$name" "$node" SKIP 0 no 0 "$(L "not running" "nicht gestartet")"; return; fi
  if [ "${NODE_ONLINE[$node]:-0}" != 1 ]; then add_result "$K" "$id" "$name" "$node" WARN 0 no 0 "$(L "node $node not reachable" "Node $node nicht erreichbar")"; return; fi
  if node_run "$node" "$tool config $id" 2>/dev/null | grep '^lock:' >/dev/null; then
    add_result "$K" "$id" "$name" "$node" WARN 0 no 0 "$(L "locked (backup running?)" "gesperrt (läuft gerade ein Backup?)")"; return
  fi
  if [ "$kind" = qemu ]; then
    ostype=$(node_run "$node" "qm config $id" 2>/dev/null | awk -F': ' '/^ostype:/{print $2}')
    if [[ "$ostype" == w* ]] && [ "$UPDATE_WINDOWS" != 1 ]; then
      add_result "$K" "$id" "$name" "$node" SKIP 0 no 0 "$(L "Windows updates are switched off" "Windows-Updates sind ausgeschaltet")"; return
    fi
    if ! node_run "$node" "qm agent $id ping" >/dev/null 2>&1; then
      if [ "$GUESTS" = all ]; then st=SKIP; else st=WARN; fi
      add_result "$K" "$id" "$name" "$node" "$st" 0 no 0 "$(L "no QEMU guest agent reachable" "kein QEMU-Guest-Agent erreichbar")"; return
    fi
    if [[ "$ostype" == w* ]]; then process_windows "$id" "$name" "$node"; return; fi
  fi

  out=$(mktemp)
  if [ "$MODE" = dryrun ]; then
    msg_info "$lbl @ $node: $(L "checking" "prüfe") ..."
    log "$lbl @ $node: check"
    exec_runner "$kind" "$id" "$node" dryrun guest > "$out" 2>&1
    parse_out "$out"; rm -f "$out"
    if [ "$P_DONE" = 1 ]; then add_result "$K" "$id" "$name" "$node" TEST "$P_PKGS" "$P_REBOOT" 0 "$(summary dryrun)"
    else add_result "$K" "$id" "$name" "$node" WARN 0 no 0 "$(L "guest not responding" "Gast nicht ansprechbar")"; fi
    return
  fi

  guest_snapshot "$tool" "$K" "$id" "$name" "$node" || { rm -f "$out"; return; }
  snapped=$SNAPPED; note=$SNOTE

  msg_info "$lbl @ $node: $(L "updating" "wird aktualisiert")${note:+ ($note)} ..."
  log "$lbl @ $node: update running${note:+ ($note)}"
  exec_runner "$kind" "$id" "$node" live guest > "$out" 2>&1
  cat "$out" >> "$LOGF"
  parse_out "$out"
  if [ "$P_DONE" != 1 ]; then
    P_HEALTH=fail; P_HNOTE="$(L "update run aborted" "Update-Lauf brach ab")"; P_LOG=$(tail -n 25 "$out")
  fi
  rm -f "$out"
  sum=$(summary live)

  if [ "$P_HEALTH" = ok ]; then
    [ "$snapped" = 1 ] && snap_delete "$tool" "$id" "$node"
    if has_warn; then st=WARN; add_detail "$K $id $name" "$P_LOG"; else st=OK; fi
    [ "$P_REF" != 0 ] && sum="$sum; $(L "package sources unreachable" "Paketquellen nicht erreichbar")"
    log "$lbl: $st - $sum"
    add_result "$K" "$id" "$name" "$node" "$st" "$P_PKGS" "$P_REBOOT" "$(changed_flag)" "$sum${note:+ ($note)}"
  else
    SNAPPED=$snapped
    guest_failed "$tool" "$K" "$id" "$name" "$node" "$P_HNOTE" "$P_LOG" "$P_PKGS" "$P_REBOOT"
  fi
}

# snapshot before the update -> SNAPPED (0/1), SNOTE; returns 1 if the guest must be skipped
guest_snapshot(){ # tool K id name node
  SNAPPED=0; SNOTE=""
  [ "$SNAPSHOT" = off ] && return 0
  msg_info "$2 $3 ($4) @ $5: $(L "creating snapshot" "Snapshot wird angelegt") ..."
  if snap_create "$1" "$3" "$5"; then SNAPPED=1; return 0; fi
  if [ "$SNAPSHOT" = required ]; then
    log "$2 $3 ($4): snapshot not possible - skipped"
    add_result "$2" "$3" "$4" "$5" WARN 0 no 0 "$(L "snapshot not possible - no update without a safety net" "Snapshot nicht möglich - ohne Sicherheitsnetz kein Update")"
    return 1
  fi
  SNOTE="$(L "without snapshot" "ohne Snapshot")"
  return 0
}

# health check failed: roll back to the snapshot (if there is one) and record the result
guest_failed(){ # tool K id name node reason details pkgs reboot
  local tool=$1 K=$2 id=$3 name=$4 node=$5 why=$6 det=$7 lbl="$2 $3 ($4)"
  log "$lbl: health check FAILED: $why"
  if [ "$SNAPPED" = 1 ]; then msg_info "$lbl: $(L "health check failed - rolling back" "Health-Check fehlgeschlagen - Rollback") ..."; fi
  if [ "$SNAPPED" = 1 ] && snap_rollback "$tool" "$id" "$node"; then
    sleep 15
    if [ "$(node_run "$node" "$tool status $id" 2>/dev/null | awk '{print $2}')" = running ]; then
      log "$lbl: rolled back, running again"
      add_result "$K" "$id" "$name" "$node" ROLLBACK 0 no 0 "$(L "update failed ($why) - rolled back to the state before the update" "Update fehlgeschlagen ($why) - auf Stand vor dem Update zurückgesetzt")"
    else
      add_result "$K" "$id" "$name" "$node" FAIL 0 no 0 "$(L "rolled back, but does not start - please check" "zurückgesetzt, startet aber nicht - bitte nachsehen")"
    fi
  elif [ "$SNAPPED" = 1 ]; then
    add_result "$K" "$id" "$name" "$node" FAIL 0 no 0 "$(L "update AND rollback failed ($why) - snapshot '$SNAP' is still there" "Update UND Rollback fehlgeschlagen ($why) - Snapshot '$SNAP' liegt noch")"
  else
    add_result "$K" "$id" "$name" "$node" FAIL "$8" "$9" 1 "$why ($(L "no snapshot - no rollback possible" "kein Snapshot - kein Rollback möglich"))"
  fi
  add_detail "$K $id $name" "$(L "Reason" "Grund"): $why"$'\n'"$det"
}

# ============================================================================
#  Windows VMs - Windows Update through the QEMU guest agent.
#  Runs as SYSTEM via qemu-ga with Windows PowerShell 5.1 and the built-in
#  Windows Update API - no extra module, nothing to install in the guest.
#  Phases: state | check | install | start | reboot
# ============================================================================
read -r -d '' WIN_PS <<'PS_EOF'
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false } catch {}
function O($s) { [Console]::Out.Write("$s`n") }
function C($s) { ("$s" -replace '[|\r\n]', ' ').Trim() }
function Pending {
  $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion'
  if ((Test-Path "$k\WindowsUpdate\Auto Update\RebootRequired") -or (Test-Path "$k\Component Based Servicing\RebootPending")) { 1 } else { 0 }
}
switch ($Phase) {
  'state' {
    $os = Get-CimInstance Win32_OperatingSystem
    O ('AU_BOOT|' + $os.LastBootUpTime.ToUniversalTime().ToString('yyyyMMddHHmmss'))
    O ('AU_OS|' + (C $os.Caption) + ' ' + $os.Version)
    $ign = $Ignore -split ','
    $run = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State='Running'" | Where-Object { $ign -notcontains $_.Name } | ForEach-Object { $_.Name })
    O ('AU_RUNNING|' + ($run -join ','))
    O ('AU_PENDING|' + (Pending)); O 'AU_DONE'; exit 0
  }
  'start' { foreach ($n in ($Names -split ',')) { if ($n) { try { Start-Service -Name $n } catch {} } }; O 'AU_DONE'; exit 0 }
  'reboot' { & shutdown.exe /r /t 15 /d p:2:17 /c 'pve-autoupdate: Windows Update' | Out-Null; O 'AU_DONE'; exit 0 }
}
try {
  $s = New-Object -ComObject Microsoft.Update.Session; $s.ClientApplicationID = 'pve-autoupdate'
  $res = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Software' and BrowseOnly=0")
} catch { O ('AU_WINERR|' + (C $_.Exception.Message)); O ('AU_WIN|0|0|0|' + (Pending)); O 'AU_DONE'; exit 0 }
$list = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($u in $res.Updates) {
  if ($u.InstallationBehavior.CanRequestUserInput) { continue }
  if (@($u.Categories | Where-Object { $_.Name -eq 'Upgrades' }).Count) { continue }   # no feature upgrades
  if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
  $kb = (@($u.KBArticleIDs) | ForEach-Object { "KB$_" }) -join ' '
  if (-not $kb) { $kb = '-' }
  O ('AU_UPD|' + $kb + '|' + (C $u.Title))
  [void]$list.Add($u)
}
if ($Phase -ne 'install' -or $list.Count -eq 0) { O ('AU_WIN|' + $list.Count + '|0|0|' + (Pending)); O 'AU_DONE'; exit 0 }
try {
  $d = $s.CreateUpdateDownloader(); $d.Updates = $list; [void]$d.Download()
  $todo = New-Object -ComObject Microsoft.Update.UpdateColl
  foreach ($u in $list) { if ($u.IsDownloaded) { [void]$todo.Add($u) } }
  if ($todo.Count -eq 0) { throw 'download failed' }
  $i = $s.CreateUpdateInstaller(); $i.Updates = $todo; $r = $i.Install()
} catch { O ('AU_WINERR|' + (C $_.Exception.Message)); O ('AU_WIN|0|' + $list.Count + '|0|' + (Pending)); O 'AU_DONE'; exit 0 }
$ok = 0; $bad = $list.Count - $todo.Count
for ($k = 0; $k -lt $todo.Count; $k++) {
  $c = $r.GetUpdateResult($k).ResultCode
  if ($c -eq 2 -or $c -eq 3) { $ok++ } else { $bad++; O ('AU_UPDFAIL|' + (C $todo.Item($k).Title) + '|' + $c) }
}
$rb = 0; if ($r.RebootRequired) { $rb = 1 }
O ('AU_WIN|' + $ok + '|' + $bad + '|' + $rb + '|' + (Pending)); O 'AU_DONE'
PS_EOF

wupd_txt(){ if [ "$1" = 1 ]; then L "1 Windows update" "1 Windows-Update"; else L "$1 Windows updates" "$1 Windows-Updates"; fi; }
win_field(){ sed -n "s/^$1|//p" <<< "$2" | head -n 1; }
# runner output -> readable lines for the mail details
win_pretty(){
  sed -n -e 's/^AU_UPD|\([^|]*\)|\(.*\)/  \2/p' \
         -e "s/^AU_UPDFAIL|\([^|]*\)|\(.*\)/  $(L FAILED FEHLER): \1 (ResultCode \2)/p" \
         -e 's/^AU_WINERR|\(.*\)/  Windows Update: \1/p' <<< "$1"
}
# the most common Windows Update errors in plain words
win_err_txt(){
  local e=$1 h=""
  case "$e" in
    *8024402[CcFf]*|*80072[Ee][Ee]7*|*80072[Ee][Ff][Dd]*|*80072[Ee][Ff][Ee]*|*80240438*)
      h="$(L "no connection to the update servers (internet, DNS or proxy)" "keine Verbindung zu den Update-Servern (Internet, DNS oder Proxy)")" ;;
    *80070422*) h="$(L "the Windows Update service is disabled" "der Windows-Update-Dienst ist deaktiviert")" ;;
    *8024001[Ee]*|*80240016*) h="$(L "Windows is busy with another update or shutting down" "Windows ist mit einem anderen Update beschäftigt oder fährt herunter")" ;;
    *8024500[Cc]*|*80244018*|*80244019*) h="$(L "blocked by policy or the WSUS server" "durch Richtlinie oder WSUS-Server blockiert")" ;;
    *80070070*) h="$(L "not enough disk space" "zu wenig Speicherplatz")" ;;
    *80070005*) h="$(L "access denied (is the guest agent running as SYSTEM?)" "Zugriff verweigert (läuft der Guest-Agent als SYSTEM?)")" ;;
  esac
  echo "${h:+$h - }$e"
}

# run one phase of WIN_PS in the VM (asynchronous: Windows Update can take an hour)
win_ps(){ # node id phase timeout_seconds [service names]
  local node=$1 id=$2 phase=$3 tmax=$4 names=${5:-} b64 pid out rc waited=0 errs=0
  b64=$({ printf "\$Phase='%s'; \$Ignore='%s'; \$Names='%s'\n" "$phase" "$WIN_IGNORE_SERVICES" "$names"; printf '%s\n' "$WIN_PS"; } |
        python3 -c 'import sys, base64; sys.stdout.write(base64.b64encode(sys.stdin.read().encode("utf-16-le")).decode())')
  pid=$(node_run "$node" "qm guest exec $id --synchronous 0 -- powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $b64" 2>/dev/null |
        python3 -c 'import json, sys
try:
    print(json.load(sys.stdin)["pid"])
except Exception:
    pass')
  [ -n "$pid" ] || return 1
  while :; do
    out=$(node_run "$node" "qm guest exec-status $id $pid" 2>/dev/null | python3 -c 'import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(4)
if not d.get("exited"):
    sys.exit(3)
sys.stdout.write((d.get("out-data", "") + d.get("err-data", "")).replace("\r", ""))')
    rc=$?
    case $rc in
      0) printf '%s\n' "$out"; return 0 ;;
      3) errs=0 ;;
      *) errs=$((errs + 1)); [ "$errs" -ge 4 ] && return 1 ;;   # agent gone (e.g. VM rebooted by itself)
    esac
    [ "$waited" -ge "$tmax" ] && return 124
    sleep 10; waited=$((waited + 10))
  done
}

# wait until the VM is back after a reboot: agent answers and the boot time changed -> WIN_STATE
win_wait_boot(){ # node id old_boot_time
  local node=$1 id=$2 old=$3 waited=0 st b
  while [ "$waited" -lt $((WIN_REBOOT_TIMEOUT * 60)) ]; do
    sleep 20; waited=$((waited + 20))
    node_run "$node" "qm agent $id ping" >/dev/null 2>&1 || continue
    st=$(win_ps "$node" "$id" state 120) || continue
    b=$(win_field AU_BOOT "$st")
    if [ -n "$b" ] && [ "$b" != "$old" ]; then WIN_STATE="$st"; return 0; fi
  done
  return 1
}

# health: every automatic service that ran before the update must run again -> WIN_HNOTE
win_health(){ # node id services_before
  local node=$1 id=$2 base=$3 i st miss=""
  for i in 1 2 3 4 5 6; do
    st=$(win_ps "$node" "$id" state 120)
    if [ -n "$(win_field AU_BOOT "$st")" ]; then
      miss=$(comm -23 <(tr ',' '\n' <<< "$base" | grep . | sort -u) <(tr ',' '\n' <<< "$(win_field AU_RUNNING "$st")" | grep . | sort -u) | tr '\n' ',' | sed 's/,$//')
      [ -z "$miss" ] && return 0
      [ "$i" = 3 ] && win_ps "$node" "$id" start 300 "$miss" >/dev/null   # give them one kick, like an admin would
    else
      miss="?"
    fi
    sleep 30
  done
  if [ "$miss" = "?" ]; then WIN_HNOTE="$(L "Windows does not respond via the guest agent" "Windows antwortet nicht über den Guest-Agent")"
  else WIN_HNOTE="$(L "services no longer running" "Dienste laufen nicht mehr"): ${miss//,/, }"; fi
  return 1
}

process_windows(){ # id name node   (VM runs, guest agent answers)
  local id=$1 name=$2 node=$3 lbl="VM $1 ($2)" st0 base boot out rc round=0 n b r p
  local ok=0 bad=0 rb=no rebooted=0 kbs="" fails="" errs="" hfail="" wlog="" sum st l t
  st0=$(win_ps "$node" "$id" state 300)
  boot=$(win_field AU_BOOT "$st0")
  if [ -z "$boot" ]; then
    add_result VM "$id" "$name" "$node" WARN 0 no 0 "$(L "Windows does not answer (PowerShell via guest agent)" "Windows antwortet nicht (PowerShell über Guest-Agent)")"; return
  fi
  base=$(win_field AU_RUNNING "$st0")
  log "$lbl @ $node: $(win_field AU_OS "$st0")"

  if [ "$MODE" = dryrun ]; then
    msg_info "$lbl @ $node: $(L "searching Windows Update" "suche Windows-Updates") ..."
    out=$(win_ps "$node" "$id" check 1800) || out=""
    if ! grep -qx AU_DONE <<< "$out"; then add_result VM "$id" "$name" "$node" WARN 0 no 0 "$(L "Windows Update search did not finish" "Windows-Update-Suche lief nicht durch")"; return; fi
    IFS='|' read -r n b r p <<< "$(win_field AU_WIN "$out")"
    errs=$(win_field AU_WINERR "$out"); [ -n "$errs" ] && errs=$(win_err_txt "$errs")
    if [ -n "$errs" ]; then add_result VM "$id" "$name" "$node" WARN 0 no 0 "Windows Update: $errs"; return; fi
    kbs=$(sed -n 's/^AU_UPD|\([^|]*\)|.*/\1/p' <<< "$out" | grep -v '^-$' | tr '\n' ' ' | sed 's/ *$//; s/ /, /g')
    if [ "${n:-0}" -gt 0 ]; then sum="$(wupd_txt "$n") $(L available verfügbar)${kbs:+ ($kbs)}"; else sum="$(L "up to date" "aktuell")"; fi
    [ "$p" = 1 ] && rb=yes
    add_result VM "$id" "$name" "$node" TEST "${n:-0}" "$rb" 0 "$sum"
    return
  fi

  guest_snapshot qm VM "$id" "$name" "$node" || return
  while [ "$round" -lt 3 ]; do       # follow-up updates often only show up after the reboot
    round=$((round + 1))
    msg_info "$lbl @ $node: $(L "installing Windows updates" "Windows-Updates werden installiert")$([ "$round" -gt 1 ] && echo " ($(L round Runde) $round)")${SNOTE:+ ($SNOTE)} ..."
    log "$lbl @ $node: Windows Update round $round"
    out=$(win_ps "$node" "$id" install $((WIN_UPDATE_TIMEOUT * 60))); rc=$?
    wlog+="$out"$'\n'; printf '%s\n' "$out" >> "$LOGF"
    if [ "$rc" = 124 ]; then hfail="$(L "Windows Update did not finish within $WIN_UPDATE_TIMEOUT min" "Windows Update nicht innerhalb von $WIN_UPDATE_TIMEOUT Min. fertig")"; break; fi
    if [ "$rc" != 0 ] || ! grep -qx AU_DONE <<< "$out"; then hfail="$(L "Windows Update run aborted" "Windows-Update-Lauf brach ab")"; break; fi
    IFS='|' read -r n b r p <<< "$(win_field AU_WIN "$out")"
    n=${n:-0}; b=${b:-0}; ok=$((ok + n)); bad=$((bad + b))
    t=$(win_field AU_WINERR "$out"); [ -n "$t" ] && errs=$(win_err_txt "$t")
    while IFS='|' read -r _ t _; do [ -n "$t" ] && fails+="$t"$'\n'; done <<< "$(grep '^AU_UPDFAIL|' <<< "$out")"
    while IFS='|' read -r _ l t; do
      [ -n "$t" ] && [ "$l" != - ] || continue
      grep -qxF "$t" <<< "$fails" || kbs+="${kbs:+, }$l"
    done <<< "$(grep '^AU_UPD|' <<< "$out")"
    { [ "$r" = 1 ] || { [ "$p" = 1 ] && [ "$n" -gt 0 ]; }; } || break      # no reboot needed - done
    if [ "$REBOOT_GUESTS" != 1 ]; then rb=yes; break; fi
    msg_info "$lbl: $(L "rebooting to finish the updates (may take up to $WIN_REBOOT_TIMEOUT min)" "Neustart, um die Updates abzuschließen (kann bis zu $WIN_REBOOT_TIMEOUT Min. dauern)") ..."
    log "$lbl: reboot (Windows Update)"
    win_ps "$node" "$id" reboot 120 >/dev/null
    if ! win_wait_boot "$node" "$id" "$boot"; then
      hfail="$(L "did not come back within $WIN_REBOOT_TIMEOUT min after the reboot" "nach dem Neustart nicht innerhalb von $WIN_REBOOT_TIMEOUT Min. zurück")"; break
    fi
    rebooted=$((rebooted + 1)); boot=$(win_field AU_BOOT "$WIN_STATE")
    [ "$n" -gt 0 ] || break
    [ "$round" = 3 ] && [ "$(win_field AU_PENDING "$WIN_STATE")" = 1 ] && rb=yes
  done

  if [ -z "$hfail" ]; then
    msg_info "$lbl: $(L "health check" "Health-Check") ..."
    sleep "$SETTLE"
    win_health "$node" "$id" "$base" || hfail="$WIN_HNOTE"
  fi
  if [ -n "$hfail" ]; then
    guest_failed qm VM "$id" "$name" "$node" "$hfail" "$(win_pretty "$wlog" | tail -n 25)" "$ok" "$rb"
    return
  fi

  [ "$SNAPPED" = 1 ] && snap_delete qm "$id" "$node"
  if [ "$ok" -gt 0 ]; then sum="$(wupd_txt "$ok") $(L installed installiert)${kbs:+ ($kbs)}"; elif [ -n "$errs" ]; then sum="Windows Update $(L failed fehlgeschlagen)"; else sum="$(L "up to date" "aktuell")"; fi
  [ "$rebooted" -gt 0 ] && sum+=", $(L rebooted "neu gestartet")"
  st=OK
  if [ "$bad" -gt 0 ] || [ -n "$errs" ]; then
    st=WARN
    [ "$bad" -gt 0 ] && sum+="; $bad $(L failed fehlgeschlagen)"
    [ -n "$errs" ] && { [ "$ok" -gt 0 ] && sum+="; Windows Update"; sum+=": $errs"; }
    add_detail "VM $id $name" "$(win_pretty "$wlog")"
  fi
  log "$lbl: $st - $sum"
  add_result VM "$id" "$name" "$node" "$st" "$ok" "$rb" "$([ "$ok" -gt 0 ] && echo 1 || echo 0)" "$sum${SNOTE:+ ($SNOTE)}"
}

# ---------------------------------------------------------------- one node
process_host(){ # node
  local n=$1 out st sum
  if [ "${NODE_ONLINE[$n]:-0}" != 1 ]; then add_result NODE "$n" "$n" "$n" WARN 0 no 0 "$(L "node not reachable" "Node nicht erreichbar")"; return; fi
  if [ "$MODE" = dryrun ]; then msg_info "Node $n: $(L "checking" "prüfe") ..."; else msg_info "Node $n: $(L "updating" "wird aktualisiert") ..."; fi
  log "NODE $n: ${MODE}"
  out=$(mktemp)
  exec_runner node "" "$n" "$MODE" host > "$out" 2>&1
  [ "$MODE" = live ] && cat "$out" >> "$LOGF"
  parse_out "$out"
  if [ "$P_DONE" != 1 ]; then
    add_detail "NODE $n" "$(tail -n 20 "$out")"; rm -f "$out"
    add_result NODE "$n" "$n" "$n" FAIL 0 no 0 "$(L "no connection / aborted" "keine Verbindung / Abbruch")"
    return
  fi
  rm -f "$out"
  sum=$(summary "$MODE")
  [ "$P_REF" != 0 ] && sum="$sum; $(L "package source error (enterprise repo without subscription?)" "Paketquellen-Fehler (Enterprise-Repo ohne Abo?)")"
  if [ "$MODE" = dryrun ]; then st=TEST
  elif [ "$P_HEALTH" != ok ]; then st=FAIL; sum="$P_HNOTE"; add_detail "NODE $n" "$P_LOG"
  elif has_warn; then st=WARN; add_detail "NODE $n" "$P_LOG"
  else st=OK; fi
  log "NODE $n: $st - $sum"
  add_result NODE "$n" "$n" "$n" "$st" "$P_PKGS" "$P_REBOOT" "$(changed_flag)" "$sum"
}

# ============================================================================
#  Mail
# ============================================================================
send_mail(){ # subject textfile [htmlfile]
  [ -n "$MAIL_TO" ] || { log "no recipient - no mail"; return 1; }
  local from="$MAIL_FROM"
  if [ -z "$from" ]; then
    if [ "$MAIL_TRANSPORT" = smtp ] && [ -n "$SMTP_USER" ]; then from="$SMTP_USER"; else from="root@$(hostname -f 2>/dev/null || hostname)"; fi
  fi
  AU_SUBJECT="$1" AU_TO="$MAIL_TO" AU_FROM="$from" AU_TRANSPORT="$MAIL_TRANSPORT" \
  AU_HOST="$SMTP_HOST" AU_PORT="$SMTP_PORT" AU_SEC="$SMTP_SECURITY" AU_USER="$SMTP_USER" AU_PASS="$SMTP_PASS" \
  python3 - "$2" "${3:-}" <<'PY'
import os, sys, ssl, shutil, smtplib, subprocess
from email.message import EmailMessage
from email.utils import formatdate, make_msgid
e = os.environ
m = EmailMessage()
m["From"] = e["AU_FROM"]; m["To"] = e["AU_TO"]; m["Subject"] = e["AU_SUBJECT"]
m["Date"] = formatdate(localtime=True); m["Message-ID"] = make_msgid()
m.set_content(open(sys.argv[1], encoding="utf-8", errors="replace").read())
if len(sys.argv) > 2 and sys.argv[2] and os.path.exists(sys.argv[2]):
    m.add_alternative(open(sys.argv[2], encoding="utf-8", errors="replace").read(), subtype="html")
if e["AU_TRANSPORT"] == "smtp":
    port = int(e.get("AU_PORT") or 587); sec = e.get("AU_SEC", "starttls")
    ctx = ssl.create_default_context()
    if sec == "ssl":
        s = smtplib.SMTP_SSL(e["AU_HOST"], port, context=ctx, timeout=30)
    else:
        s = smtplib.SMTP(e["AU_HOST"], port, timeout=30); s.ehlo()
        if sec == "starttls":
            s.starttls(context=ctx); s.ehlo()
    if e.get("AU_USER"):
        s.login(e["AU_USER"], e.get("AU_PASS", ""))
    s.send_message(m); s.quit()
else:
    sendmail = shutil.which("sendmail") or "/usr/sbin/sendmail"
    sys.exit(subprocess.run([sendmail, "-t", "-oi"], input=m.as_bytes()).returncode)
PY
}

badge(){
  local bg fg t
  case "$1" in
    OK)       bg='#e6f4ea'; fg='#137333'; t='OK' ;;
    WARN)     bg='#fef7e0'; fg='#9a6700'; t="$(L WARNING WARNUNG)" ;;
    FAIL)     bg='#fce8e6'; fg='#c5221f'; t="$(L ERROR FEHLER)" ;;
    ROLLBACK) bg='#fde7d9'; fg='#b3470b'; t="$(L "ROLLED BACK" "ZURÜCKGESETZT")" ;;
    SKIP)     bg='#f1f3f4'; fg='#5f6368'; t="$(L skipped übersprungen)" ;;
    TEST)     bg='#e8f0fe'; fg='#1967d2'; t='TEST' ;;
    UP)       bg='#e6f4ea'; fg='#137333'; t='online' ;;
    PENDING)  bg='#fef7e0'; fg='#9a6700'; t="$(L "reboot pending" "Neustart offen")" ;;
    *)        bg='#f1f3f4'; fg='#5f6368'; t="$1" ;;
  esac
  printf '<span style="background:%s;color:%s;padding:2px 9px;border-radius:11px;font-weight:600;font-size:12px;white-space:nowrap">%s</span>' "$bg" "$fg" "$t"
}

html_open(){ # kicker headline color emoji time
  # kaimazon.de look: ink header, amber kicker, status colour as a bar below
  local logo='<span style="display:inline-block;width:34px;height:34px;line-height:34px;border-radius:9px;background:#F2A93B;color:#14181F;font-weight:800;font-size:15px;text-align:center;letter-spacing:-.5px">KF</span>'
  has_logo && logo="<img src=\"$LOGO_URL\" width=\"34\" height=\"34\" alt=\"KF\" style=\"display:block;border-radius:9px\">"
  cat <<EOF
<div style="background:#14181F;padding:28px 0;font-family:Inter,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif">
<div style="max-width:660px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #262D3B">
<div style="background:#1F2531;padding:22px 26px 20px;color:#EEF1F6">
<table cellpadding="0" cellspacing="0" style="border-collapse:collapse"><tr><td style="padding-right:12px;vertical-align:middle">$logo</td>
<td style="vertical-align:middle;font-family:'IBM Plex Mono',Consolas,Menlo,monospace;font-size:12px;color:#F2A93B;letter-spacing:.6px">&gt;_ $1</td></tr></table>
<div style="font-family:'Schibsted Grotesk',Inter,-apple-system,Segoe UI,Arial,sans-serif;font-size:26px;font-weight:800;margin-top:14px;letter-spacing:-.3px">$4&nbsp; $2</div>
<div style="font-size:13px;color:#A8B0BE;margin-top:4px">$5</div>
</div>
<div style="height:4px;background:$3;line-height:4px;font-size:0">&nbsp;</div>
EOF
}
html_close(){ # footer
  local links
  links="<span style=\"color:#EEF1F6;font-weight:700\">$(he "$AUTHOR")</span> &middot; <a href=\"$WEBSITE\" style=\"color:#F2A93B;text-decoration:none\">${WEBSITE#https://}</a>"
  has_repo && links="$links &middot; <a href=\"$REPO_URL\" style=\"color:#A8B0BE;text-decoration:none\">GitHub</a>"
  echo "<div style=\"padding:14px 24px 16px;color:#80868b;font-size:12px;line-height:1.5;border-top:1px solid #eceff1\">$1</div>"
  echo "<div style=\"background:#14181F;padding:16px 24px;color:#6C7484;font-size:12px;line-height:1.7\">"
  echo "<span style=\"font-family:'IBM Plex Mono',Consolas,Menlo,monospace;color:#F2A93B\">&gt;_</span> pve-autoupdate $VERSION &middot; $links"
  has_donate && echo "<br><a href=\"$DONATE_URL\" style=\"display:inline-block;margin-top:8px;background:#F2A93B;color:#201503;padding:6px 14px;border-radius:999px;font-weight:700;text-decoration:none\">&#9829; $(L "Support on Liberapay" "Auf Liberapay unterstützen")</a>"
  echo '</div></div></div>'
}
text_footer(){
  echo
  echo "-- pve-autoupdate $VERSION by $AUTHOR - ${WEBSITE#https://}"
  has_repo && echo "   $REPO_URL"
  has_donate && echo "   $(DONATE_TXT) $DONATE_URL"
  return 0
}

weekday(){
  case "$1" in
    Mon) L Monday Montag ;; Tue) L Tuesday Dienstag ;; Wed) L Wednesday Mittwoch ;;
    Thu) L Thursday Donnerstag ;; Fri) L Friday Freitag ;; Sat) L Saturday Samstag ;;
    Sun) L Sunday Sonntag ;; *) printf '%s' "$1" ;;
  esac
}
# ---------------------------------------------------------------- update window
valid_window(){ [[ "$1" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$ ]] && [ "${1%-*}" != "${1#*-}" ]; }
hm_min(){ echo $(( 10#${1%:*} * 60 + 10#${1#*:} )); }
# 0 = updates may run now (no window set, window ignored, or inside it)
in_window(){
  [ -n "$UPDATE_WINDOW" ] && [ "${IGNORE_WINDOW:-0}" != 1 ] || return 0
  local now s e
  # PVE_AUTOUPDATE_CLOCK: file with a fake "HH:MM", only for the tests
  if [ -n "${PVE_AUTOUPDATE_CLOCK:-}" ]; then now=$(hm_min "$(cat "$PVE_AUTOUPDATE_CLOCK")"); else now=$(hm_min "$(date +%H:%M)"); fi
  s=$(hm_min "${UPDATE_WINDOW%-*}"); e=$(hm_min "${UPDATE_WINDOW#*-}")
  if [ "$s" -le "$e" ]; then [ "$now" -ge "$s" ] && [ "$now" -lt "$e" ]
  else [ "$now" -ge "$s" ] || [ "$now" -lt "$e" ]; fi          # crosses midnight, e.g. 23:00-04:00
}
window_over(){ L "update window ($UPDATE_WINDOW) over - next run" "Zeitfenster ($UPDATE_WINDOW) vorbei - beim nächsten Lauf"; }
window_txt(){
  if [ -n "$UPDATE_WINDOW" ]; then L "only ${UPDATE_WINDOW/-/ - }" "nur ${UPDATE_WINDOW/-/ - } Uhr"
  else L "no limit" "keine Einschränkung"; fi
}

describe_schedule(){
  local s="$SCHEDULE"
  if [[ "$s" =~ ^\*-\*-\*\ ([0-9]{2}:[0-9]{2}) ]]; then L "daily at ${BASH_REMATCH[1]}" "täglich um ${BASH_REMATCH[1]} Uhr"
  elif [[ "$s" =~ ^([A-Z][a-z]{2})\ \*-\*-\*\ ([0-9]{2}:[0-9]{2}) ]]; then
    L "every $(weekday "${BASH_REMATCH[1]}") at ${BASH_REMATCH[2]}" "jeden $(weekday "${BASH_REMATCH[1]}") um ${BASH_REMATCH[2]} Uhr"
  elif [[ "$s" =~ ^([A-Z][a-z]{2})\ \*-\*-01\.\.07\ ([0-9]{2}:[0-9]{2}) ]]; then
    L "first $(weekday "${BASH_REMATCH[1]}") of the month at ${BASH_REMATCH[2]}" "jeden ersten $(weekday "${BASH_REMATCH[1]}") im Monat um ${BASH_REMATCH[2]} Uhr"
  else printf '%s' "$s"; fi
  [ -n "$UPDATE_WINDOW" ] && L ", until ${UPDATE_WINDOW#*-} at the latest" ", längstens bis ${UPDATE_WINDOW#*-} Uhr"
  return 0
}

# build report -> REPORT_SUBJECT, REPORT_TXT, REPORT_HTML, counters
build_report(){
  local st total okc failc warnc rbc skipc pkgsum chg head col emo subj pfx cell cur
  st="$(stamp)"
  total=$(grep -c . "$RESULTS"); okc=$(awk -F'|' '$5=="OK"' "$RESULTS" | wc -l)
  failc=$(awk -F'|' '$5=="FAIL"' "$RESULTS" | wc -l); warnc=$(awk -F'|' '$5=="WARN"' "$RESULTS" | wc -l)
  rbc=$(awk -F'|' '$5=="ROLLBACK"' "$RESULTS" | wc -l); skipc=$(awk -F'|' '$5=="SKIP"' "$RESULTS" | wc -l)
  pkgsum=$(awk -F'|' '$5!="ROLLBACK"{s+=$6} END{print s+0}' "$RESULTS")
  chg=$(awk -F'|' '$8==1' "$RESULTS" | wc -l)
  PROBLEMS=$((failc + warnc + rbc)); CHANGES=$chg; FAILS=$failc

  pfx=""; [ "$MODE" = dryrun ] && pfx="[TEST] "
  if [ "$failc" -gt 0 ]; then head="$(L "Update errors" "Fehler beim Update")"; col="#c5221f"; emo="&#9888;&#65039;"; subj="⚠️ $failc $(L "error(s)" "Fehler")"
  elif [ "$rbc" -gt 0 ]; then head="$(L "Update rolled back" "Update zurückgesetzt")"; col="#b3470b"; emo="&#8617;&#65039;"; subj="↩️ $rbc $(L "update(s) rolled back" "Update(s) zurückgesetzt")"
  elif [ "$warnc" -gt 0 ]; then head="$(L "Updates with warnings" "Updates mit Warnungen")"; col="#9a6700"; emo="&#9888;&#65039;"; subj="⚠️ $warnc $(L "warning(s)" "Warnung(en)")"
  elif [ "$MODE" = dryrun ] && [ "$pkgsum" -gt 0 ]; then head="$(L "Dry run" Testlauf): $(pkgs_txt "$pkgsum") $(L available verfügbar)"; col="#1967d2"; emo="&#129514;"; subj="🧪 $(pkgs_txt "$pkgsum") $(L available verfügbar)"
  elif [ "$chg" -gt 0 ]; then head="$(L "Updates installed" "Updates installiert")"; col="#137333"; emo="&#9989;"; subj="✅ $(pkgs_txt "$pkgsum") $(L updated aktualisiert)"
  else head="$(L "Everything up to date" "Alles aktuell")"; col="#137333"; emo="&#9989;"; subj="✅ $(L "everything up to date" "alles aktuell")"; fi
  REPORT_SUBJECT="${pfx}[$TITLE] Updates: $subj"

  REPORT_TXT="$WORK/report.txt"; REPORT_HTML="$WORK/report.html"
  sorted(){ awk -F'|' '{o=($1=="NODE")?0:(($1=="LXC")?1:2); print $4"|"o"|"$0}' "$RESULTS" | sort -t'|' -k1,1 -k2,2n -k4,4n | cut -d'|' -f3-; }
  {
    echo "pve-autoupdate - $TITLE - $st ($(L mode Modus): $MODE)"
    L "Machines: $total | OK: $okc | Warnings: $warnc | Rolled back: $rbc | Errors: $failc | Skipped: $skipc | Packages: $pkgsum" \
      "Maschinen: $total | OK: $okc | Warnungen: $warnc | Zurückgesetzt: $rbc | Fehler: $failc | Übersprungen: $skipc | Pakete: $pkgsum"; echo
    echo "--------------------------------------------------------------------------------"
    sorted | while IFS='|' read -r k id name node s pk rb ch sm; do
      [ "$rb" = yes ] && sm="$sm [$(L "reboot needed" "Neustart nötig")]"
      printf '%-4s %-5s %-20s %-10s %-9s %s\n' "$k" "$id" "${name:0:20}" "$node" "$s" "$sm"
    done
    if [ -s "$DETAILS" ]; then echo; echo "=== Details ==="; cat "$DETAILS"; fi
    text_footer
  } > "$REPORT_TXT"

  cell="padding:9px 12px;border-bottom:1px solid #eceff1;font-size:14px;color:#37474f"
  {
    html_open "PROXMOX &middot; AUTO-UPDATE &middot; $(he "$TITLE")${pfx:+ &middot; $(L "DRY RUN" TESTLAUF)}" "$head" "$col" "$emo" "$st"
    echo "<div style=\"padding:16px 22px 8px;font-size:14px;color:#37474f;line-height:1.9\"><b>$total</b> $(L machines Maschinen) &middot; <b style=\"color:#1a73e8\">$pkgsum</b> $(L packages Pakete) &middot; <b style=\"color:$([ "$failc" -gt 0 ] && echo '#c5221f' || echo '#137333')\">$failc</b> $(L errors Fehler) &middot; <b>$rbc</b> $(L "rolled back" zurückgesetzt) &middot; <b>$warnc</b> $(L warnings Warnungen)</div>"
    echo '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:4px 0">'
    echo "<tr style=\"background:#fafafa\"><th style=\"$cell;text-align:left;font-size:12px;color:#80868b\">$(L Machine Maschine)</th><th style=\"$cell;text-align:left;font-size:12px;color:#80868b\">Status</th><th style=\"$cell;text-align:right;font-size:12px;color:#80868b\">$(L Reboot Neustart)</th></tr>"
    cur=""
    sorted | while IFS='|' read -r k id name node s pk rb ch sm; do
      if [ "$node" != "$cur" ]; then
        echo "<tr><td colspan=3 style=\"padding:12px 12px 4px;font-size:12px;font-weight:700;color:#5f6368;letter-spacing:.5px\">&#128421; NODE $(he "$node")</td></tr>"
        cur="$node"
      fi
      local icon="&#128230;" rbcell='<span style="color:#bdc1c6">&#8211;</span>' idtxt=""
      [ "$k" = NODE ] && icon="&#128421;"; [ "$k" = VM ] && icon="&#128187;"
      [ "$k" = NODE ] || idtxt=" <span style=\"color:#9aa0a6\">#$id</span>"
      if [ "$rb" = yes ]; then
        local rt; rt="$(L "reboot needed" "Neustart nötig")"
        if [ "$MODE" = live ] && { { [ "$k" = NODE ] && [ "$REBOOT_HOSTS" = 1 ]; } || { [ "$k" != NODE ] && [ "$REBOOT_GUESTS" = 1 ]; }; }; then rt="&#8635; $(L "reboot follows" "Neustart folgt")"; fi
        rbcell="<span style=\"background:#fef7e0;color:#9a6700;padding:3px 10px;border-radius:11px;font-weight:600;font-size:12px;white-space:nowrap\">$rt</span>"
      fi
      echo "<tr><td style=\"$cell\">$icon <b>$(he "$name")</b>$idtxt<div style=\"font-size:12px;color:#9aa0a6;margin-top:2px\">$(he "$sm")</div></td><td style=\"$cell\">$(badge "$s")</td><td style=\"$cell;text-align:right\">$rbcell</td></tr>"
    done
    echo '</table>'
    if [ -s "$DETAILS" ]; then
      echo '<div style="margin:10px 20px;padding:12px 14px;background:#f8f9fa;border-radius:8px"><div style="font-weight:700;color:#5f6368;font-size:13px;margin-bottom:6px">Details</div><pre style="margin:0;font-size:12px;color:#5f6368;white-space:pre-wrap">'
      he "$(cat "$DETAILS")"
      echo '</pre></div>'
    fi
    html_close "$(L Schedule Zeitplan): $(he "$(describe_schedule)") &middot; Snapshots: $SNAPSHOT &middot; $(L "Node reboot" "Node-Neustart"): $([ "$REBOOT_HOSTS" = 1 ] && L automatic automatisch || L manual manuell)<br>$(L "A snapshot is taken before every update; if the health check fails afterwards, the guest is rolled back automatically." "Vor jedem Update wird ein Snapshot angelegt; schlägt der Health-Check danach fehl, wird automatisch zurückgesetzt.")<br>Node $(he "$SELF") &middot; Log: $LOGF"
  } > "$REPORT_HTML"
}

should_mail(){ # problems changes
  case "$NOTIFY" in
    never)   return 1 ;;
    errors)  [ "$1" -gt 0 ] ;;
    changes) [ "$1" -gt 0 ] || [ "$2" -gt 0 ] ;;
    always)  return 0 ;;
    *)       [ "$1" -gt 0 ] ;;
  esac
}

# ============================================================================
#  Reboots
# ============================================================================
boot_id(){ node_run "$1" "cat /proc/sys/kernel/random/boot_id" 2>/dev/null; }

wait_node_back(){ # node old_boot_id
  local n=$1 old=$2 i id
  for i in $(seq 1 80); do        # up to ~25 minutes
    sleep 20
    id=$(boot_id "$n")
    [ -n "$id" ] && [ "$id" != "$old" ] || continue
    if [ -n "$CLUSTER_NAME" ] && ! pvecm status 2>/dev/null | grep -iE 'Quorate:[[:space:]]+Yes' >/dev/null; then continue; fi
    sleep 60   # give the guests time to start
    return 0
  done
  return 1
}

save_expected(){
  mkdir -p "$STATE"
  list_guests | awk -F'|' '$5=="running"{print $1"|"$3"|"$4}' > "$STATE/expected-guests"
  echo "$NODES" > "$STATE/expected-nodes"
}

reboot_phase(){
  local reb_hosts="" n k id node old abort=0
  if ! in_window; then
    log "update window ($UPDATE_WINDOW) is over - reboots postponed to the next run"
    [ "$INTERACTIVE" = 1 ] && msg_warn "$(L "Update window is over - reboots follow on the next run" "Zeitfenster vorbei - Neustarts folgen beim nächsten Lauf")"
    return 0
  fi
  [ "$REBOOT_HOSTS" = 1 ] && reb_hosts=$(awk -F'|' '$1=="NODE" && ($5=="OK"||$5=="WARN") && $7=="yes"{print $4}' "$RESULTS" | tr '\n' ' ' | sed 's/ *$//')
  if [ "$REBOOT_GUESTS" = 1 ]; then
    awk -F'|' '($1=="LXC"||$1=="VM") && ($5=="OK"||$5=="WARN") && $7=="yes"{print $1"|"$2"|"$4}' "$RESULTS" |
    while IFS='|' read -r k id node; do
      in_list "$node" "$reb_hosts" && continue          # reboots with the node anyway
      node=$(guest_field "$id" 4); [ -n "$node" ] || continue
      log "reboot $k $id @ $node"
      [ "$INTERACTIVE" = 1 ] && msg_ok "$k $id: $(L "rebooting" "wird neu gestartet")"
      if [ "$k" = VM ]; then node_run "$node" "qm reboot $id" >>"$LOGF" 2>&1; else node_run "$node" "pct reboot $id" >>"$LOGF" 2>&1; fi
    done
  fi
  [ -n "${reb_hosts// /}" ] || return 0

  save_expected
  # other nodes one after another - never two at once, or quorum is lost
  for n in $reb_hosts; do
    [ "$n" = "$SELF" ] && continue
    old=$(boot_id "$n")
    log "reboot node $n"
    msg_info "Node $n: $(L "rebooting, waiting for it to come back" "Neustart, warte auf Rückkehr") ..."
    node_run "$n" "systemctl reboot" >>"$LOGF" 2>&1
    if ! wait_node_back "$n" "$old"; then
      log "node $n did not come back after reboot - further reboots aborted"
      msg_error "Node $n: $(L "did not come back - further reboots aborted" "nicht zurückgekommen - weitere Neustarts abgebrochen")"
      abort=1; break
    fi
    log "node $n back"
    msg_ok "Node $n: $(L "back online" "wieder online")"
  done
  if [ "$abort" = 0 ] && in_list "$SELF" "$reb_hosts"; then
    touch "$STATE/reboot-pending"
    log "rebooting this node ($SELF) last - post check follows after boot"
    msg_warn "Node $SELF: $(L "rebooting now - a post check runs after boot" "startet jetzt neu - Nachkontrolle läuft nach dem Start")"
    ev_end rebooting
    sleep 5; systemctl reboot
  else
    cmd_postcheck inline
  fi
}

# ============================================================================
#  Control interface for the web UI container (JSON)
#  Every run writes its events to $STATE/runs/<run id>.jsonl - timer runs too,
#  so the UI shows the whole history. The UI reaches the node over SSH with a
#  key that may only run "pve-autoupdate remote" (see cmd_pair / cmd_remote).
# ============================================================================
RUNS="$STATE/runs"
EVF=""
AUTH_KEYS="${PVE_AUTOUPDATE_AUTHKEYS:-/root/.ssh/authorized_keys}"

# ev TYPE key=value ... -> one JSON line in the event file of the current run
ev(){
  [ -n "${EVF:-}" ] || return 0
  python3 -c '
import json, sys, time
d = {"ev": sys.argv[1], "ts": int(time.time())}
for a in sys.argv[2:]:
    k, _, v = a.partition("=")
    d[k] = v
print(json.dumps(d, ensure_ascii=False))' "$@" >> "$EVF" 2>/dev/null
  return 0
}
ev_open(){
  local f
  RUN_ID="${PVE_AUTOUPDATE_RUN_ID:-}"
  mkdir -p "$RUNS"
  if ! [[ "$RUN_ID" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    RUN_ID=$(date +%Y%m%d-%H%M%S)
    while [ -e "$RUNS/$RUN_ID.jsonl" ]; do RUN_ID=$(date +%Y%m%d-%H%M%S); done
  fi
  EVF="$RUNS/$RUN_ID.jsonl"; : > "$EVF"
  echo "$RUN_ID" > "$STATE/last-run"
  # keep the last 200 runs
  printf '%s\n' "${RUNS:?}"/*.jsonl | sort -r | tail -n +201 | while read -r f; do rm -f "${f:?}"; done
}
ev_end(){ [ "${EV_ENDED:-0}" = 1 ] && return 0; EV_ENDED=1; ev end status="$1"; }
is_running(){ ! ( exec 9>"$LOCKF"; flock -n 9 ) 2>/dev/null; }
json_err(){ printf '{"ok": false, "error": "%s"}\n' "$1"; return 1; }

guest_os(){ # type node id -> ostype from the config (pmxcfs, readable on every node)
  local f="/etc/pve/nodes/$2/qemu-server/$3.conf"
  [ "$1" = lxc ] && f="/etc/pve/nodes/$2/lxc/$3.conf"
  sed -n '/^\[/q; s/^ostype: *//p' "$f" 2>/dev/null | head -n 1
}

# everything the overview page needs, in one call
cmd_inventory(){
  need_root; need_pve; load_config; load_nodes
  local v n id type name node status tmpl sel running=0 pass=0
  is_running && running=1
  [ -n "$SMTP_PASS" ] && pass=1
  {
    printf 'M|%s|%s\n' version "$VERSION" lang "$UI_LANG" cluster "$CLUSTER_NAME" self "$SELF" \
      running "$running" last_run "$(cat "$STATE/last-run" 2>/dev/null)" schedule_text "$(describe_schedule)" \
      next_run "$(next_run)" smtp_pass_set "$pass" reboot_pending "$([ -f "$STATE/reboot-pending" ] && echo 1 || echo 0)" \
      in_window "$(in_window && echo 1 || echo 0)"
    for n in $NODES; do echo "N|$n|${NODE_IP[$n]:-}|${NODE_ONLINE[$n]:-0}"; done
    while IFS='|' read -r -u 3 id type name node status tmpl; do
      [ -n "$id" ] || continue
      sel=0; is_selected "$id" "$type" && sel=1
      echo "G|$id|$type|$name|$node|$status|$tmpl|$sel|$(guest_os "$type" "$node" "$id")"
    done 3< <(list_guests)
    for v in $CONF_VARS; do [ "$v" = SMTP_PASS ] || printf 'C|%s|%s\n' "$v" "${!v}"; done
  } | python3 -c '
import json, os, sys
d = {"nodes": [], "guests": [], "config": {}, "last": {}}
for l in sys.stdin.read().split("\n"):
    if l.startswith("M|"):
        _, k, v = l.split("|", 2); d[k] = v
    elif l.startswith("N|"):
        _, n, ip, on = l.split("|", 3)
        d["nodes"].append({"name": n, "ip": ip, "online": on == "1"})
    elif l.startswith("G|"):
        f = l.split("|", 8)
        d["guests"].append({"id": int(f[1]), "type": f[2], "name": f[3], "node": f[4], "status": f[5],
                            "template": f[6] == "1", "selected": f[7] == "1", "os": f[8]})
    elif l.startswith("C|"):
        _, k, v = l.split("|", 2); d["config"][k] = v
for k in ("running", "smtp_pass_set", "reboot_pending", "in_window"):
    d[k] = d.get(k) == "1"
# last real result per guest / node: "update" from live runs, "check" from dry runs
try:
    files = sorted((f for f in os.listdir(sys.argv[1]) if f.endswith(".jsonl")), reverse=True)[:60]
except OSError:
    files = []
for f in files:
    mode = None
    for line in open(os.path.join(sys.argv[1], f), encoding="utf-8", errors="replace"):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("ev") == "start":
            mode = e.get("mode")
        elif e.get("ev") == "result" and mode and e.get("status") != "SKIP":
            slot = "check" if mode == "dryrun" else "update"
            ent = d["last"].setdefault(e.get("kind", "") + ":" + e.get("id", ""), {})
            if slot not in ent:
                ent[slot] = {"run": f[:-6], "ts": e.get("ts"), "status": e.get("status"), "summary": e.get("summary", ""),
                             "pkgs": int(e.get("pkgs") or 0), "reboot": e.get("reboot") == "yes"}
print(json.dumps(d, ensure_ascii=False))' "$RUNS"
}

HISTORY_PY='
import json, os, sys
d, n, running, last = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1", sys.argv[4]
files = sorted(f for f in os.listdir(d) if f.endswith(".jsonl")) if os.path.isdir(d) else []
out = []
for f in reversed(files[-n:] if n else []):
    r = {"id": f[:-6], "status": "running", "results": 0, "problems": 0, "changes": 0, "fails": 0}
    for line in open(os.path.join(d, f), encoding="utf-8", errors="replace"):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        t = e.get("ev")
        if t == "start":
            r.update(start=e["ts"], mode=e.get("mode"), trigger=e.get("trigger"), only=e.get("only", ""))
        elif t == "result":
            r["results"] += 1
        elif t == "report":
            r["subject"] = e.get("subject", "")
            for k in ("problems", "changes", "fails"):
                r[k] = int(e.get(k) or 0)
        elif t == "end":
            r.update(status=e.get("status"), end=e["ts"])
        elif t == "postcheck":
            r["postcheck"] = {"nodes": e.get("nodes"), "guests": e.get("guests"), "problems": int(e.get("problems") or 0)}
    if r["status"] == "running" and not (running and r["id"] == last):
        r["status"] = "aborted"
    out.append(r)
print(json.dumps(out, ensure_ascii=False))
'
# last runs, newest first: id, start, mode, status, counts
cmd_history(){
  need_root
  local n="${1:-30}" running=0
  [[ "$n" =~ ^[0-9]+$ ]] || n=30
  is_running && running=1
  python3 -c "$HISTORY_PY" "$RUNS" "$n" "$running" "$(cat "$STATE/last-run" 2>/dev/null)"
}

# events of one run from line <from> on - the UI polls this for the live view
cmd_events(){
  need_root
  local id="${1:-last}" from="${2:-0}"
  [ "$id" = last ] && id=$(cat "$STATE/last-run" 2>/dev/null)
  [[ "$id" =~ ^[0-9]{8}-[0-9]{6}$ ]] || { json_err "invalid run id"; return 1; }
  [[ "$from" =~ ^[0-9]+$ ]] || from=0
  [ -f "$RUNS/$id.jsonl" ] || return 0
  tail -n +"$((from + 1))" "$RUNS/$id.jsonl"
}

# like "run", but in the background (survives a dropped SSH connection); prints the run id
cmd_start(){
  need_root; need_pve; load_config
  local a t id self
  for a in "$@"; do
    case "$a" in
      --dry-run|--reboot|--no-reboot|--ignore-window) ;;
      --only=*) t="${a#--only=}"
                for t in ${t//,/ }; do
                  [[ "$t" =~ ^[0-9]+$ || "$t" =~ ^node:[A-Za-z0-9._-]+$ ]] || { json_err "invalid target: $t"; return 1; }
                done ;;
      *) json_err "invalid option: $a"; return 1 ;;
    esac
  done
  is_running && { json_err "already running"; return 1; }
  mkdir -p "$RUNS"
  id=$(date +%Y%m%d-%H%M%S)
  while [ -e "$RUNS/$id.jsonl" ]; do id=$(date +%Y%m%d-%H%M%S); done
  self=$(readlink -f "$0")
  if command -v systemd-run >/dev/null 2>&1; then
    systemd-run --quiet --collect --unit "pve-autoupdate-ui-$id" --setenv=PVE_AUTOUPDATE_TRIGGER=ui \
      --setenv=PVE_AUTOUPDATE_RUN_ID="$id" "$self" run "$@" >/dev/null 2>&1 || { json_err "systemd-run failed"; return 1; }
  else
    PVE_AUTOUPDATE_TRIGGER=ui PVE_AUTOUPDATE_RUN_ID=$id setsid "$self" run "$@" </dev/null >/dev/null 2>&1 &
  fi
  printf '{"ok": true, "run": "%s"}\n' "$id"
}

cfg_valid(){ # key value
  case "$1" in
    UI_LANG)        [[ "$2" =~ ^(en|de)$ ]] ;;
    GUESTS)         [[ "$2" == all || "$2" =~ ^[0-9\ ]*$ ]] ;;
    EXCLUDE)        [[ "$2" =~ ^[0-9\ ]*$ ]] ;;
    INCLUDE_VMS|UPDATE_HOSTS|UPDATE_SERVICES|REBOOT_GUESTS|REBOOT_HOSTS|UPDATE_WINDOWS) [[ "$2" =~ ^[01]$ ]] ;;
    SNAPSHOT)       [[ "$2" =~ ^(required|optional|off)$ ]] ;;
    NOTIFY)         [[ "$2" =~ ^(never|errors|changes|always)$ ]] ;;
    MAIL_TRANSPORT) [[ "$2" =~ ^(system|smtp)$ ]] ;;
    SMTP_SECURITY)  [[ "$2" =~ ^(starttls|ssl|none)$ ]] ;;
    SMTP_PORT|SETTLE|WIN_UPDATE_TIMEOUT|WIN_REBOOT_TIMEOUT) [[ "$2" =~ ^[0-9]{1,5}$ ]] ;;
    SCHEDULE)       [ -n "$2" ] && systemd-analyze calendar "$2" >/dev/null 2>&1 ;;
    UPDATE_WINDOW)  [ -z "$2" ] || valid_window "$2" ;;
    MAIL_TO|MAIL_FROM) [[ "$2" =~ ^[A-Za-z0-9._%+@,\ -]*$ ]] ;;
    SMTP_HOST)      [[ "$2" =~ ^[A-Za-z0-9.:-]*$ ]] ;;
    WIN_IGNORE_SERVICES) [[ "$2" =~ ^[A-Za-z0-9_.,\ -]*$ ]] ;;
    SMTP_USER|SMTP_PASS|TITLE) [[ "$2" != *$'\n'* && ${#2} -le 200 ]] ;;
    *) return 1 ;;
  esac
}

CONFIG_PY='
import json, sys
try:
    d = json.load(sys.stdin)
    assert isinstance(d, dict)
except Exception:
    print("!"); sys.exit()
for k, v in d.items():
    if isinstance(v, bool):
        v = int(v)
    if v is None:
        v = ""
    if isinstance(v, list):
        v = " ".join(str(x) for x in v)
    print("%s\t%s" % (k, str(v).encode().hex()))
'
# config set < {"KEY": "value", ...} - checks every value, writes all or nothing
cmd_config(){
  [ "${1:-}" = set ] || die "$(L "usage" "Aufruf"): pve-autoupdate config set < settings.json"
  need_root; need_pve; load_config
  local k hex v changed="" old_sched="$SCHEDULE" pairs all
  all=$(echo $CONF_VARS)
  pairs=$(python3 -c "$CONFIG_PY")
  [ "$pairs" = "!" ] && { json_err "invalid JSON"; return 1; }
  declare -A NEW=()
  while IFS=$'\t' read -r k hex; do
    [ -n "$k" ] || continue
    v=$(printf '%b' "$(sed 's/../\\x&/g' <<< "$hex")")
    { [[ "$k" =~ ^[A-Z_]+$ ]] && in_list "$k" "$all" && cfg_valid "$k" "$v"; } || { json_err "invalid value for $k"; return 1; }
    NEW[$k]=$v
  done <<< "$pairs"
  for k in "${!NEW[@]}"; do
    [ "${!k}" = "${NEW[$k]}" ] && continue
    printf -v "$k" '%s' "${NEW[$k]}"; changed="$changed $k"
  done
  if [ -n "$changed" ]; then
    write_config
    log "config changed via UI:$changed"
    if [ "$SCHEDULE" != "$old_sched" ] && [ -f "/etc/systemd/system/$UNIT.timer" ]; then install_units; fi
  fi
  python3 -c 'import json, sys; print(json.dumps({"ok": True, "changed": sys.argv[1].split()}))' "$changed"
}

cmd_log(){ # [lines]
  need_root
  local n="${1:-200}"; [[ "$n" =~ ^[0-9]+$ ]] || n=200; [ "$n" -gt 5000 ] && n=5000
  [ -f "$LOGF" ] && tail -n "$n" "$LOGF"
  return 0
}

# pair "<ssh public key>" - the web UI container may then run "pve-autoupdate remote"
# on this node and nothing else (no shell, no forwarding)
cmd_pair(){
  need_root
  local key="${*:-}"
  [ -n "$key" ] || read -r key
  [[ "$key" =~ ^(ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|ssh-rsa)\ [A-Za-z0-9+/=]+ ]] || die "$(L "not an SSH public key" "kein öffentlicher SSH-Schlüssel")"
  key="${BASH_REMATCH[0]}"
  [ -x "$BIN" ] || die "$(L "install pve-autoupdate on this node first" "erst pve-autoupdate auf diesem Node installieren")"
  cmd_unpair
  mkdir -p "$(dirname "$AUTH_KEYS")"
  echo "command=\"$BIN remote\",restrict $key pve-autoupdate-ui" >> "$AUTH_KEYS"
  log "web UI key paired"
  msg_ok "$(L "Web UI paired - its key may only run pve-autoupdate on this node" "Weboberfläche verbunden - ihr Schlüssel darf nur pve-autoupdate auf diesem Node ausführen")"
}
cmd_unpair(){
  need_root
  [ -f "$AUTH_KEYS" ] || return 0
  local t; t=$(grep -v ' pve-autoupdate-ui$' "$AUTH_KEYS")
  # write in place: on Proxmox the file is a symlink into /etc/pve/priv
  if [ -n "$t" ]; then printf '%s\n' "$t" > "$AUTH_KEYS"; else : > "$AUTH_KEYS"; fi
}

# forced command of the paired key: only what the web UI needs
cmd_remote(){
  local c="${SSH_ORIGINAL_COMMAND:-}" ok=0
  local -a a=()
  [[ "$c" =~ ^[A-Za-z0-9\ ._,:=-]*$ ]] && read -r -a a <<< "$c"
  [ "${a[0]:-}" = pve-autoupdate ] && a=("${a[@]:1}")
  case "${a[0]:-}" in
    version|inventory|history|events|start|log|test-mail|api-fingerprint) ok=1 ;;
    config) [ "${a[1]:-}" = set ] && [ "${#a[@]}" = 2 ] && ok=1 ;;
  esac
  [ "$ok" = 1 ] || { json_err "not allowed"; exit 1; }
  INTERACTIVE=0
  dispatch "${a[@]}"
}

# ============================================================================
#  Commands
# ============================================================================
cmd_run(){
  local a mailtest=0 id type name node status tmpl reboot=""
  MODE=live; ONLY=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|dryrun|-n) MODE=dryrun ;;
      --mail)      mailtest=1 ;;
      --only)      ONLY="${2:-}"; shift ;;
      --only=*)    ONLY="${1#--only=}" ;;
      --reboot)    reboot=1 ;;
      --no-reboot) reboot=0 ;;
      --ignore-window) IGNORE_WINDOW=1 ;;
      *) die "$(L "unknown option" "unbekannte Option"): $1" ;;
    esac
    shift
  done
  ONLY="${ONLY//,/ }"
  for a in $ONLY; do
    [[ "$a" =~ ^[0-9]+$ || "$a" =~ ^node:[A-Za-z0-9._-]+$ ]] || die "$(L "invalid target" "ungültiges Ziel"): $a"
  done
  need_root; need_pve; load_config
  # --reboot / --no-reboot overrule the config for this one run
  [ -n "$reboot" ] && { REBOOT_GUESTS=$reboot; REBOOT_HOSTS=$reboot; }
  [ "$MODE" = dryrun ] && IGNORE_WINDOW=1        # a check changes nothing - allowed any time
  exec 9>"$LOCKF"; flock -n 9 || die "$(L "pve-autoupdate is already running" "pve-autoupdate läuft bereits")"
  mkdir -p "$STATE"
  if ! in_window; then
    if [ "$INTERACTIVE" = 1 ] && confirm "$(L "It is outside the update window ($UPDATE_WINDOW). Update anyway?" "Es ist außerhalb des Update-Zeitfensters ($UPDATE_WINDOW). Trotzdem aktualisieren?")"; then
      IGNORE_WINDOW=1
    else
      if [ "$INTERACTIVE" = 0 ]; then              # timer or web UI: leave a trace in the history
        ev_open
        ev start mode="$MODE" only="$ONLY" trigger="${PVE_AUTOUPDATE_TRIGGER:-cli}" version="$VERSION" title="$TITLE"
      fi
      log "outside the update window ($UPDATE_WINDOW) - nothing done"
      ev_end window
      echo "$(L "Outside the update window" "Außerhalb des Update-Zeitfensters") ($UPDATE_WINDOW) - $(L "nothing done (--ignore-window to force)" "nichts getan (--ignore-window erzwingt es)")"
      return 0
    fi
  fi
  if [ -f "$LOGF" ] && [ "$(stat -c %s "$LOGF")" -gt 5242880 ]; then mv -f "$LOGF" "$LOGF.1"; fi
  load_nodes
  WORK=$(mktemp -d); RESULTS="$WORK/results"; DETAILS="$WORK/details"; : > "$RESULTS"; : > "$DETAILS"
  trap 'stop_spinner; rm -rf "$WORK"' EXIT
  ev_open
  ev start mode="$MODE" only="$ONLY" trigger="${PVE_AUTOUPDATE_TRIGGER:-cli}" version="$VERSION" nodes="$NODES" cluster="$CLUSTER_NAME" title="$TITLE"
  log "=== pve-autoupdate $VERSION START ($MODE${ONLY:+, only: $ONLY}) - nodes: $NODES ==="
  if [ "$INTERACTIVE" = 1 ]; then
    header_info
    if [ "$MODE" = dryrun ]; then msg_ok "$(L "Dry run - nothing will be changed" "Testlauf - es wird nichts verändert")"; fi
    msg_ok "$([ -n "$CLUSTER_NAME" ] && echo "Cluster $CLUSTER_NAME: " )$(L "nodes" "Nodes"): $NODES"
  fi

  while IFS='|' read -r -u 3 id type name node status tmpl; do
    [ -n "$id" ] || continue
    [ "$tmpl" = 1 ] && continue
    if [ -n "$ONLY" ]; then in_list "$id" "$ONLY" || continue
    else is_selected "$id" "$type" || continue; fi
    if ! in_window; then add_result "$( [ "$type" = qemu ] && echo VM || echo LXC )" "$id" "$name" "$node" SKIP 0 no 0 "$(window_over)"; continue; fi
    process_guest "$id" "$type" "$name" "$node" "$status"
  done 3< <(list_guests)

  for node in $NODES; do
    if [ -n "$ONLY" ]; then in_list "node:$node" "$ONLY" || continue
    else [ "$UPDATE_HOSTS" = 1 ] || continue; fi
    if ! in_window; then add_result NODE "$node" "$node" "$node" SKIP 0 no 0 "$(window_over)"; continue; fi
    process_host "$node"
  done

  build_report
  ev report subject="$REPORT_SUBJECT" problems="$PROBLEMS" changes="$CHANGES" fails="$FAILS"
  cat "$REPORT_TXT" >> "$LOGF"
  if [ "$INTERACTIVE" = 1 ]; then
    echo
    if [ "$FAILS" -gt 0 ]; then msg_error "${REPORT_SUBJECT}"
    elif [ "$PROBLEMS" -gt 0 ]; then msg_warn "${REPORT_SUBJECT}"
    else msg_ok "${REPORT_SUBJECT}"; fi
  else
    cat "$REPORT_TXT"
  fi
  if { [ "$MODE" = live ] && should_mail "$PROBLEMS" "$CHANGES"; } || { [ "$MODE" = dryrun ] && [ "$mailtest" = 1 ]; }; then
    msg_info "$(L "Sending mail" "Mail wird verschickt") ..."
    if send_mail "$REPORT_SUBJECT" "$REPORT_TXT" "$REPORT_HTML"; then
      log "mail sent: $REPORT_SUBJECT"; [ "$INTERACTIVE" = 1 ] && msg_ok "$(L "Mail sent to" "Mail verschickt an") $MAIL_TO"
    else
      log "WARNING: sending mail failed"; [ "$INTERACTIVE" = 1 ] && msg_error "$(L "Sending mail failed" "Mailversand fehlgeschlagen")"
    fi
  fi

  [ "$MODE" = live ] && reboot_phase
  log "=== pve-autoupdate END ($MODE) ==="
  if [ "$FAILS" -eq 0 ]; then ev_end ok; else ev_end fail; fi
  [ "$FAILS" -eq 0 ]
}

# post check after node reboots: are all nodes and guests back?
cmd_postcheck(){
  local mode="${1:-inline}" i miss run id name node st kern b nb=0 gb=0 nt=0 gt=0 ts subject head col emo body html cell
  load_config
  if [ "$mode" = boot ]; then [ -f "$STATE/reboot-pending" ] || return 0; fi
  log "post check ($mode)"
  load_nodes
  if [ -n "$CLUSTER_NAME" ]; then
    for i in $(seq 1 36); do pvecm status 2>/dev/null | grep -iE 'Quorate:[[:space:]]+Yes' >/dev/null && break; sleep 10; done
  fi
  sleep 30
  if [ -f "$STATE/expected-guests" ]; then
    for i in $(seq 1 36); do
      run=" $(list_guests | awk -F'|' '$5=="running"{printf "%s ", $1}') "; miss=0
      while IFS='|' read -r id name node; do in_list "$id" "$run" || miss=1; done < "$STATE/expected-guests"
      [ "$miss" = 0 ] && break; sleep 10
    done
  fi
  load_nodes
  local work; work=$(mktemp -d)
  local probe='r=$(uname -r); n=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed "s#.*/vmlinuz-##" | sort -V | tail -n 1); if [ "$r" = "$n" ] && [ ! -f /var/run/reboot-required ]; then echo "OK|$r"; else echo "PENDING|$r"; fi'
  : > "$work/nodes"
  for node in $NODES; do
    st=$(node_run "$node" "$probe" 2>/dev/null | tail -n 1); [ -n "$st" ] || st="OFFLINE|?"
    echo "$node|$st" >> "$work/nodes"
  done
  run=" $(list_guests | awk -F'|' '$5=="running"{printf "%s ", $1}') "
  : > "$work/guests"
  if [ -f "$STATE/expected-guests" ]; then
    while IFS='|' read -r id name node; do
      if in_list "$id" "$run"; then echo "$id|$name|$node|UP"; else echo "$id|$name|$node|DOWN"; fi
    done < "$STATE/expected-guests" > "$work/guests"
  fi
  nt=$(grep -c . "$work/nodes"); gt=$(grep -c . "$work/guests")
  nb=$(awk -F'|' '$2=="OFFLINE"' "$work/nodes" | wc -l); gb=$(awk -F'|' '$4!="UP"' "$work/guests" | wc -l)
  ts="$(stamp)"
  if [ $((nb + gb)) -eq 0 ]; then
    head="$(L "After reboot: everything back online" "Nach dem Neustart: alles wieder online")"; col="#137333"; emo="&#9989;"
    subject="✅ [$TITLE] $(L "after reboot everything back online" "nach Neustart alles wieder online")"
  else
    head="$(L "After reboot: problems" "Nach dem Neustart: Probleme")"; col="#c5221f"; emo="&#9888;&#65039;"
    subject="⚠️ [$TITLE] $(L "after reboot $((nb + gb)) problem(s)" "nach Neustart $((nb + gb)) Problem(e)")"
  fi
  body="$work/body.txt"; html="$work/body.html"
  {
    echo "$(L "Post check after reboot" "Nachkontrolle nach Neustart") - $TITLE - $ts"
    echo "$(L "Nodes reachable" "Nodes erreichbar"): $((nt - nb))/$nt | $(L "Guests online" "Gäste online"): $((gt - gb))/$gt"
    echo "--- Nodes ---";  awk -F'|' '{printf "%-12s %-8s Kernel %s\n", $1, $2, $3}' "$work/nodes"
    echo "--- $(L Guests Gäste) ---"; awk -F'|' '{printf "#%-5s %-20s @%-10s %s\n", $1, $2, $3, $4}' "$work/guests"
    text_footer
  } > "$body"
  cat "$body" >> "$LOGF"
  [ "$mode" = boot ] || cat "$body"
  cell="padding:9px 12px;border-bottom:1px solid #eceff1;font-size:14px;color:#37474f"
  {
    html_open "PROXMOX &middot; $(L "POST CHECK" NACHKONTROLLE) &middot; $(he "$TITLE")" "$head" "$col" "$emo" "$ts"
    echo "<div style=\"padding:16px 22px 4px;font-size:14px;color:#37474f\"><b>$((nt - nb))/$nt</b> $(L "nodes reachable" "Nodes erreichbar") &middot; <b>$((gt - gb))/$gt</b> $(L "guests online" "Gäste online")</div>"
    echo '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse">'
    while IFS='|' read -r node st kern; do
      case "$st" in OK) b=$(badge UP);; PENDING) b=$(badge PENDING);; *) b=$(badge FAIL);; esac
      echo "<tr><td style=\"$cell\">&#128421; <b>$(he "$node")</b></td><td style=\"$cell\">$b</td><td style=\"$cell;text-align:right;color:#80868b;font-size:12px\">Kernel $(he "$kern")</td></tr>"
    done < "$work/nodes"
    while IFS='|' read -r id name node st; do
      if [ "$st" = UP ]; then b=$(badge UP); else b=$(badge FAIL); fi
      echo "<tr><td style=\"$cell\">&#128230; <b>$(he "$name")</b> <span style=\"color:#9aa0a6\">#$id</span></td><td style=\"$cell;color:#80868b;font-size:12px\">@$(he "$node")</td><td style=\"$cell;text-align:right\">$b</td></tr>"
    done < "$work/guests"
    echo '</table>'
    html_close "$(L "Automatic check after the update reboots" "Automatische Kontrolle nach den Update-Neustarts")"
  } > "$html"
  if should_mail $((nb + gb)) 1; then send_mail "$subject" "$body" "$html" && log "mail sent: $subject"; fi
  # the run that rebooted gets the result of the post check
  [ -n "${EVF:-}" ] || { EVF="$STATE/runs/$(cat "$STATE/last-run" 2>/dev/null).jsonl"; [ -f "$EVF" ] || EVF=""; }
  ev postcheck nodes="$((nt - nb))/$nt" guests="$((gt - gb))/$gt" problems="$((nb + gb))"
  rm -f "$STATE/reboot-pending"; rm -rf "$work"
  return 0
}

cmd_test_mail(){
  need_root; load_config
  { [ "$NOTIFY" != never ] && [ -n "$MAIL_TO" ]; } || die "$(L "no mail notification configured (pve-autoupdate setup)" "keine Mail-Benachrichtigung eingerichtet (pve-autoupdate setup)")"
  local w; w=$(mktemp -d)
  { L "Test mail from pve-autoupdate on $(hostname). If you can read this, sending works." \
      "Testmail von pve-autoupdate auf $(hostname). Wenn du das liest, funktioniert der Versand."; echo; text_footer; } > "$w/t.txt"
  { html_open "PROXMOX &middot; AUTO-UPDATE &middot; $(he "$TITLE")" "$(L "Test mail" Testmail)" "#1967d2" "&#9993;&#65039;" "$(stamp)"
    echo "<div style=\"padding:18px 24px;font-size:14px;color:#37474f\">$(L "If you can read this, notifications arrive." "Wenn du das liest, kommen die Benachrichtigungen an.")<br>$(L Recipient Empfänger): $(he "$MAIL_TO") &middot; $(L Transport Versand): $(he "$MAIL_TRANSPORT")</div>"
    html_close "Node $(he "$(hostname)")"; } > "$w/t.html"
  msg_info "$(L "Sending test mail" "Testmail wird verschickt") ..."
  if send_mail "[$TITLE] $(L "Test mail from pve-autoupdate" "Testmail von pve-autoupdate")" "$w/t.txt" "$w/t.html"; then
    msg_ok "$(L "Test mail handed over to" "Testmail übergeben an") $MAIL_TO"
    [ "$MAIL_TRANSPORT" = system ] && msg_warn "$(L "Nothing arrives? Check the Proxmox mail system:" "Kommt nichts an? Proxmox-Mailsystem prüfen:") journalctl -u postfix -n 30"
  else
    rm -rf "$w"; die "$(L "sending failed" "Versand fehlgeschlagen")"
  fi
  rm -rf "$w"
}

guests_text(){
  if [ "$GUESTS" = all ]; then
    L "all containers" "alle Container"; [ "$INCLUDE_VMS" = 1 ] && L " + VMs" " + VMs"
    [ -n "$EXCLUDE" ] && L ", except $EXCLUDE" ", außer $EXCLUDE"
  else printf '%s' "${GUESTS:-$(L none keine)}"; fi
}
notify_text(){
  case "$NOTIFY" in
    never) L never nie ;; errors) L "on problems" "bei Problemen" ;;
    changes) L "on problems and changes" "bei Problemen und Änderungen" ;; always) L always immer ;;
  esac
  [ "$NOTIFY" != never ] && [ -n "$MAIL_TO" ] && printf ' -> %s (%s)' "$MAIL_TO" "$MAIL_TRANSPORT"
  return 0
}
next_run(){
  local n; n=$(systemctl show "$UNIT.timer" -p NextElapseUSecRealtime --value 2>/dev/null)
  [ -n "$n" ] && [ "$n" != n/a ] && { printf '%s' "$n"; return; }
  L "not scheduled" "nicht geplant"
}

cmd_status(){
  load_config
  echo -e "${BL}pve-autoupdate $VERSION${CL}  ($(L "language" "Sprache"): $UI_LANG)"
  echo "  $(L "Guests          " "Gäste           "): $(guests_text)"
  echo "  $(L "Update nodes    " "Nodes updaten   "): $(yesno_txt "$UPDATE_HOSTS")"
  echo "  $(L "Apps            " "Anwendungen     "): $(yesno_txt "$UPDATE_SERVICES")"
  echo "  $(L "Windows Update  " "Windows Update  "): $(yesno_txt "$UPDATE_WINDOWS")"
  echo "  $(L "Snapshots       " "Snapshots       "): $SNAPSHOT"
  echo "  $(L "Reboots         " "Neustarts       "): $(L guests Gäste) $(yesno_txt "$REBOOT_GUESTS"), Nodes $(yesno_txt "$REBOOT_HOSTS")"
  echo "  $(L "Schedule        " "Zeitplan        "): $(describe_schedule)  ($SCHEDULE)"
  echo "  $(L "Update window   " "Zeitfenster     "): $(window_txt)"
  echo "  $(L "Next run        " "Nächster Lauf   "): $(next_run)"
  echo "  $(L "Notification    " "Benachrichtigung"): $(notify_text)"
  if ui_exists; then echo "  $(L "Web UI          " "Weboberfläche   "): $(ui_url || L "container $(ui_ctid), address unknown" "Container $(ui_ctid), Adresse unbekannt")"; fi
  echo
  if [ -f "$LOGF" ]; then echo "$(L "Last log lines" "Letzte Log-Zeilen") ($LOGF):"; tail -n 15 "$LOGF"; fi
  return 0
}

install_units(){
  cat > /etc/systemd/system/$UNIT.service <<EOF
[Unit]
Description=pve-autoupdate: updates for Proxmox nodes, containers and apps
After=network-online.target pve-cluster.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN run
TimeoutStartSec=8h
EOF
  cat > /etc/systemd/system/$UNIT.timer <<EOF
[Unit]
Description=pve-autoupdate schedule

[Timer]
OnCalendar=$SCHEDULE
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF
  cat > /etc/systemd/system/$UNIT-postcheck.service <<EOF
[Unit]
Description=pve-autoupdate: post check after update reboot
After=pve-guests.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN postcheck boot

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  # Persistent=true catches up on missed runs - after a schedule change that
  # would start an update right away. Setting the stamp prevents it.
  mkdir -p /var/lib/systemd/timers && touch "/var/lib/systemd/timers/stamp-$UNIT.timer"
  systemctl enable --now "$UNIT.timer" >/dev/null 2>&1
  systemctl restart "$UNIT.timer" >/dev/null 2>&1
  systemctl enable "$UNIT-postcheck.service" >/dev/null 2>&1
}

write_example(){
  mkdir -p "$SVC_DIR" "$STATE"
  [ -f "$SVC_DIR/example.conf.example" ] || cat > "$SVC_DIR/example.conf.example" <<'EOF'
# Own service for pve-autoupdate. Copy to <name>.conf and adjust.
# Eigener Dienst fuer pve-autoupdate. Nach <name>.conf kopieren und anpassen.
#
# Runs inside the guest (or on the node) with sh. HEALTH_CMD must exit 0,
# otherwise the guest is rolled back to the snapshot.
NAME="Vaultwarden"
TARGET="100"                      # guest ID(s) or node name, separated by spaces
VERSION_CMD='/opt/vaultwarden/bin/vaultwarden --version | awk "{print \$2}"'
UPDATE_CMD='/usr/local/sbin/update-vaultwarden.sh'
HEALTH_CMD='systemctl is-active --quiet vaultwarden && curl -sk -o /dev/null https://127.0.0.1:8000/'
EOF
}

# Copy this script to $BIN. Started via `bash -c "$(curl ...)"` there is no
# file - then the script is downloaded again, shown with its SHA256.
# Scheduled runs only use the local copy.
install_self(){
  local src tmp="" sha
  src=$(readlink -f "$0" 2>/dev/null)
  if [ -n "$src" ] && [ -f "$src" ] && grep -q '^VERSION=' "$src" && grep -q 'pve-autoupdate' "$src"; then
    [ "$src" = "$BIN" ] && { write_example; return 0; }
    tmp="$src"
  else
    has_repo || die "$(L "no repository configured in this copy - download the file and run: bash pve-autoupdate.sh" "kein Repository in dieser Kopie eingetragen - Datei herunterladen und ausführen: bash pve-autoupdate.sh")"
    tmp=$(mktemp)
    msg_info "$(L "Downloading pve-autoupdate" "pve-autoupdate wird heruntergeladen") ..."
    curl -fsSL "$RAW_URL" -o "$tmp" || { rm -f "$tmp"; die "$(L "download failed" "Download fehlgeschlagen"): $RAW_URL"; }
    msg_ok "$(L "Downloaded" "Heruntergeladen"): $RAW_URL"
  fi
  bash -n "$tmp" || die "$(L "the downloaded script is broken" "das heruntergeladene Script ist fehlerhaft")"
  sha=$(sha256sum "$tmp" | cut -d' ' -f1)
  if [ "$INTERACTIVE" = 1 ]; then
    echo -e "${INFO}${YW}SHA256: ${sha}${CL}"
  fi
  mkdir -p "$(dirname "$BIN")"; install -m 755 "$tmp" "$BIN"
  [ "$tmp" != "$src" ] && rm -f "$tmp"
  write_example
  msg_ok "$(L "Installed to" "Installiert nach") $BIN"
}

cmd_self_update(){
  need_root
  has_repo || die "$(L "no repository configured in this copy" "kein Repository in dieser Kopie eingetragen")"
  local yes=0 tmp old new oldv newv
  [ "${1:-}" = --yes ] && yes=1
  tmp=$(mktemp)
  msg_info "$(L "Checking for a new version" "Suche nach neuer Version") ..."
  curl -fsSL "$RAW_URL" -o "$tmp" || { rm -f "$tmp"; die "$(L "download failed" "Download fehlgeschlagen")"; }
  bash -n "$tmp" || { rm -f "$tmp"; die "$(L "the downloaded script is broken" "das heruntergeladene Script ist fehlerhaft")"; }
  old=$(sha256sum "$BIN" 2>/dev/null | cut -d' ' -f1); new=$(sha256sum "$tmp" | cut -d' ' -f1)
  oldv=$VERSION; newv=$(grep -m1 '^VERSION=' "$tmp" | cut -d'"' -f2)
  if [ "$old" = "$new" ]; then rm -f "$tmp"; msg_ok "$(L "Already up to date" "Bereits aktuell") ($oldv)"; return 0; fi
  msg_ok "$(L "New version available" "Neue Version verfügbar"): $oldv -> $newv"
  echo -e "${TAB}${YW}$(L "old" "alt") SHA256: $old${CL}"
  echo -e "${TAB}${YW}$(L "new" "neu") SHA256: $new${CL}"
  if [ "$yes" = 0 ]; then
    if confirm "$(L "Show changes (diff)?" "Änderungen anzeigen (diff)?")"; then
      diff -u "$BIN" "$tmp" | less -R 2>/dev/null || diff -u "$BIN" "$tmp"
    fi
    confirm "$(L "Install the update?" "Update installieren?")" || { rm -f "$tmp"; msg_warn "$(L "Update cancelled" "Update abgebrochen")"; return 0; }
  fi
  install -m 755 "$tmp" "$BIN"; rm -f "$tmp"
  load_config; [ -f "$CONF" ] && install_units
  msg_ok "$(L "Updated to" "Aktualisiert auf") $newv"
  # the new copy brings the matching web UI along
  if ui_exists; then PVE_AUTOUPDATE_UI_SRC="" "$BIN" ui-update || true; fi
}

cmd_uninstall(){
  need_root
  systemctl disable --now "$UNIT.timer" >/dev/null 2>&1
  systemctl disable "$UNIT-postcheck.service" >/dev/null 2>&1
  rm -f /etc/systemd/system/$UNIT.service /etc/systemd/system/$UNIT.timer /etc/systemd/system/$UNIT-postcheck.service
  systemctl daemon-reload
  cmd_unpair
  if [ "${1:-}" = --purge ] && ui_exists; then ( cmd_ui_remove ) || true; fi
  rm -f "$BIN"
  if [ "${1:-}" = --purge ]; then
    rm -rf "$CONF_DIR" "$STATE" "$LOGF" "$LOGF.1"
    msg_ok "$(L "pve-autoupdate completely removed" "pve-autoupdate komplett entfernt")"
  else
    msg_ok "$(L "pve-autoupdate removed. Settings are still in $CONF_DIR (remove with: uninstall --purge)" "pve-autoupdate entfernt. Einstellungen liegen noch in $CONF_DIR (löschen mit: uninstall --purge)")"
  fi
}

# ============================================================================
#  Web UI container - a small Debian LXC with the web UI, set up from the node:
#  container, packages, TLS certificate, an SSH key that may only run
#  pve-autoupdate (see cmd_pair), pinned SSH host key and API certificate,
#  systemd service. Nothing to do by hand.
# ============================================================================
UI_CONF="$CONF_DIR/ui.conf"
UI_RAW="https://raw.githubusercontent.com/$REPO/main/ui"
UI_FILES="pve-autoupdate-ui.py static/index.html static/app.css static/app.js static/logo.svg"
UI_DIR=/opt/pve-autoupdate-ui      # inside the container
UI_ETC=/etc/pve-autoupdate-ui      # inside the container
UI_PORT=8443
UI_UNIT_TXT='[Unit]
Description=pve-autoupdate web UI
After=network-online.target
Wants=network-online.target

[Service]
User=pveau-ui
ExecStart=/usr/bin/python3 /opt/pve-autoupdate-ui/pve-autoupdate-ui.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target'
# runs inside the container: service user, SSH key, TLS certificate ($1 hostname, $2 IP)
UI_PREP='set -e
id -u pveau-ui >/dev/null 2>&1 || useradd --system --no-create-home --home-dir /opt/pve-autoupdate-ui --shell /usr/sbin/nologin pveau-ui
mkdir -p /etc/pve-autoupdate-ui; cd /etc/pve-autoupdate-ui
[ -f id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C pve-autoupdate-ui -f id_ed25519
[ -f ui.key ] || openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 3650 \
  -subj "/CN=$1" -addext "subjectAltName=DNS:$1,IP:$2" -keyout ui.key -out ui.crt 2>/dev/null
chown -R pveau-ui: /etc/pve-autoupdate-ui; chmod 700 /etc/pve-autoupdate-ui; chmod 600 id_ed25519 ui.key'

ui_ctid(){ sed -n 's/^UI_CTID=\([0-9][0-9]*\)$/\1/p' "$UI_CONF" 2>/dev/null | head -n 1; }
ui_exists(){ local id; id=$(ui_ctid); [ -n "$id" ] && pct status "$id" >/dev/null 2>&1; }
ui_ip(){ pct exec "$1" -- ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n 1; }
ui_url(){ local id ip; id=$(ui_ctid); [ -n "$id" ] && ip=$(ui_ip "$id") && [ -n "$ip" ] && echo "https://$ip:$UI_PORT"; }

# What people look for after the install: where do I open the web UI?
ui_box(){ # [container-ip] [sha256] [dhcp]
  local id url ctip="${1:-}" fp="${2:-}" mode="${3:-}" rule
  id=$(ui_ctid); [ -n "$id" ] || return 0
  [ -n "$ctip" ] || ctip=$(ui_ip "$id")
  [ -n "$ctip" ] || return 0
  url="https://$ctip:$UI_PORT"
  [ -n "$fp" ] || fp=$(pct exec "$id" -- openssl x509 -in "$UI_ETC/ui.crt" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
  [ -n "$mode" ] || { pct config "$id" 2>/dev/null | grep -q 'ip=dhcp' && mode=dhcp; }
  rule="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo -e "${TAB}${ACD}${rule}${CL}"
  echo -e "${TAB}${AC}${BOLD}$(L "WEB UI READY" "WEBOBERFLÄCHE BEREIT")${CL}"
  echo
  echo -e "${TAB}${MUT}$(L "Open in your browser:" "Im Browser öffnen:")${CL}"
  echo -e "${TAB}${AC}${BOLD}${url}${CL}"
  echo
  echo -e "${TAB}${MUT}$(L "Login      " "Anmeldung  ")${CL} ${INK}$(L "your Proxmox user, e.g. root, realm \"Linux PAM\"" "dein Proxmox-Benutzer, z. B. root, Realm \"Linux PAM\"")${CL}"
  echo -e "${TAB}${MUT}$(L "Browser    " "Browser    ")${CL} ${INK}$(L "warns once about the certificate: Advanced, then Continue" "warnt einmal vor dem Zertifikat: Erweitert, dann Weiter")${CL}"
  [ -n "$fp" ] && echo -e "${TAB}${MUT}SHA256     ${CL} ${MUT}${fp}${CL}"
  [ "$mode" = dhcp ] && echo -e "${TAB}${MUT}$(L "Tip        " "Tipp       ")${CL} ${INK}$(L "reserve $ctip in your router so it stays the same" "$ctip im Router fest reservieren, damit sie gleich bleibt")${CL}"
  echo -e "${TAB}${ACD}${rule}${CL}"
  return 0
}
valid_ipv4(){ [[ "$1" =~ ^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$ ]]; }
valid_cidr(){ valid_ipv4 "${1%/*}" && [[ "$1" =~ /([89]|[12][0-9]|3[0-2])$ ]]; }

# SHA256 of the certificate pveproxy serves: an own/ACME one if there, else the cluster-signed one
api_fingerprint(){
  local c=/etc/pve/local/pveproxy-ssl.pem
  [ -f "$c" ] || c=/etc/pve/local/pve-ssl.pem
  openssl x509 -in "$c" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 | tr -d : | tr 'A-F' 'a-f'
}
# asked by the web UI when the API certificate changed (renewal) - over SSH, whose host key is pinned
cmd_api_fingerprint(){
  local fp; fp=$(api_fingerprint)
  [ -n "$fp" ] || { json_err "no API certificate found"; return 1; }
  printf '{"ok": true, "sha256": "%s"}\n' "$fp"
}

ui_get_files(){ # dir - from the checkout next to this script, $PVE_AUTOUPDATE_UI_SRC, or GitHub
  local d="$1" src f
  src="${PVE_AUTOUPDATE_UI_SRC:-$(dirname "$(readlink -f "$0")")/ui}"
  mkdir -p "$d/static"
  if [ -f "$src/pve-autoupdate-ui.py" ]; then
    for f in $UI_FILES; do cp "$src/$f" "$d/$f" || return 1; done
  else
    has_repo || return 1
    for f in $UI_FILES; do
      curl -fsSL "$UI_RAW/$f" -o "$d/$f" || { msg_error "$(L "download failed" "Download fehlgeschlagen"): $UI_RAW/$f"; return 1; }
    done
  fi
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$d/pve-autoupdate-ui.py" 2>/dev/null
}
ui_push(){ # ctid dir
  local f
  pct exec "$1" -- mkdir -p "$UI_DIR/static" || return 1
  for f in $UI_FILES; do pct push "$1" "$2/$f" "$UI_DIR/$f" --perms 644 || return 1; done
}
ui_template(){ # template storage -> newest Debian 13/12 standard template (downloaded if needed)
  local t
  t=$(pveam list "$1" 2>/dev/null | awk '{print $1}' | grep -E '/debian-1[23]-standard_[^/]*_amd64\.tar\.(zst|gz|xz)$' | sort -V | tail -n 1)
  if [ -z "$t" ]; then
    pveam update >/dev/null 2>&1
    t=$(pveam available --section system 2>/dev/null | awk '{print $2}' | grep -E '^debian-1[23]-standard_.*_amd64\.tar\.(zst|gz|xz)$' | sort -V | tail -n 1)
    [ -n "$t" ] || return 1
    pveam download "$1" "$t" >/dev/null 2>&1 || return 1
    t="$1:vztmpl/$t"
  fi
  echo "$t"
}
ui_storages(){ pvesm status -content "$1" 2>/dev/null | awk 'NR>1 && $3=="active" {print $1}'; }
ui_pick_storage(){ # content -> a sensible default
  local l s; l=$(ui_storages "$1")
  for s in local-lvm local-zfs local; do in_list "$s" "${l//$'\n'/ }" && { echo "$s"; return 0; }; done
  printf '%s\n' "$l" | head -n 1
}
ui_bridges(){ local b; for b in /sys/class/net/*/bridge; do [ -d "$b" ] && basename "$(dirname "$b")"; done; }

ui_wizard(){ # storage and network - sets the locals of cmd_ui_install
  local l n s c opts=()
  wt --title "$(L "Web UI" "Weboberfläche")" --yes-button "$(L Install Installieren)" --no-button "$(L Cancel Abbrechen)" --yesno "$(L \
"A small container with the web UI is created on this node ($SELF):\n\n  ID $id · Debian · 1 core · 256 MB RAM · 2 GB disk\n\nEverything is set up automatically: packages, certificate, an SSH key that may only run pve-autoupdate, and the service. You sign in with your Proxmox user." \
"Auf diesem Node ($SELF) wird ein kleiner Container mit der Weboberfläche angelegt:\n\n  ID $id · Debian · 1 Kern · 256 MB RAM · 2 GB Platte\n\nAlles wird automatisch eingerichtet: Pakete, Zertifikat, ein SSH-Schlüssel, der nur pve-autoupdate ausführen darf, und der Dienst. Angemeldet wird mit deinem Proxmox-Benutzer.")" 17 78 || return 1
  l=$(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 && $3=="active" {print $1" "$2}')
  if [ "$(printf '%s\n' "$l" | grep -c .)" -gt 1 ]; then
    while read -r n s; do opts+=("$n" "$s"); done <<< "$l"
    storage=$(wt --title "$(L Storage Speicher)" --default-item "$storage" --menu "$(L "Where should the container disk go?" "Wohin soll die Platte des Containers?")" 16 60 6 "${opts[@]}") || return 1
  fi
  l=$(ui_bridges)
  if [ "$(printf '%s\n' "$l" | grep -c .)" -gt 1 ]; then
    opts=(); for n in $l; do opts+=("$n" ""); done
    bridge=$(wt --title "$(L Network Netzwerk)" --default-item "$bridge" --menu "$(L "Network bridge:" "Netzwerk-Bridge:")" 14 50 5 "${opts[@]}") || return 1
  fi
  c=$(wt --title "$(L Network Netzwerk)" --menu "$(L "IP address of the web UI:" "IP-Adresse der Weboberfläche:")" 12 70 2 \
      dhcp   "$(L "automatic (DHCP)" "automatisch (DHCP)")" \
      static "$(L "fixed address" "feste Adresse")") || return 1
  if [ "$c" = dhcp ]; then ip=dhcp; gw=""; return 0; fi
  while :; do
    ip=$(wt --title "$(L Network Netzwerk)" --inputbox "$(L "IP address with prefix, e.g. 192.168.1.50/24:" "IP-Adresse mit Präfix, z.B. 192.168.1.50/24:")" 9 70 "${ip#dhcp}") || return 1
    valid_cidr "$ip" && break
    wt --msgbox "$(L "Please enter it like 192.168.1.50/24." "Bitte so eingeben: 192.168.1.50/24.")" 8 50
  done
  while :; do
    gw=$(wt --title "$(L Network Netzwerk)" --inputbox "Gateway:" 9 70 "${gw:-${ip%.*}.1}") || return 1
    valid_ipv4 "$gw" && break
  done
}

cmd_ui_install(){
  need_root; need_pve; load_config; load_nodes
  local id="" storage="" tstorage="" bridge=vmbr0 vlan="" ip=dhcp gw="" name=pve-autoupdate-ui yes=0
  local tmp tmpl net ctip nodeip fp hk pub uifp i up=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --ctid)     id="${2:-}"; shift ;;
      --storage)  storage="${2:-}"; shift ;;
      --template-storage) tstorage="${2:-}"; shift ;;
      --bridge)   bridge="${2:-}"; shift ;;
      --vlan)     vlan="${2:-}"; shift ;;
      --ip)       ip="${2:-}"; shift ;;
      --gw)       gw="${2:-}"; shift ;;
      --hostname) name="${2:-}"; shift ;;
      --yes|-y)   yes=1 ;;
      *) die "$(L "unknown option" "unbekannte Option"): $1" ;;
    esac
    shift
  done
  ui_exists && die "$(L "the web UI is already installed (container $(ui_ctid)) - update it with: pve-autoupdate ui-update" "die Weboberfläche ist schon installiert (Container $(ui_ctid)) - aktualisieren mit: pve-autoupdate ui-update")"
  [ -n "$id" ] || id=$(pvesh get /cluster/nextid 2>/dev/null)
  [ -n "$storage" ] || storage=$(ui_pick_storage rootdir)
  [ -n "$tstorage" ] || tstorage=$(ui_pick_storage vztmpl)
  if [ "$INTERACTIVE" = 1 ] && [ "$yes" = 0 ] && command -v whiptail >/dev/null; then
    ui_wizard || { msg_warn "$(L "Web UI not installed" "Weboberfläche nicht installiert")"; return 1; }
  fi
  [[ "$id" =~ ^[1-9][0-9]{2,8}$ ]]            || die "$(L "invalid container ID" "ungültige Container-ID"): $id"
  [ -n "$storage" ] && [ -n "$tstorage" ]     || die "$(L "no storage for containers / templates found" "kein Speicher für Container / Vorlagen gefunden")"
  [[ "$bridge" =~ ^[A-Za-z0-9_.-]+$ ]]        || die "$(L "invalid bridge" "ungültige Bridge"): $bridge"
  [[ -z "$vlan" || "$vlan" =~ ^[1-9][0-9]{0,3}$ ]] || die "$(L "invalid VLAN" "ungültiges VLAN"): $vlan"
  { [ "$ip" = dhcp ] || valid_cidr "$ip"; }   || die "$(L "invalid IP (dhcp or 192.168.1.50/24)" "ungültige IP (dhcp oder 192.168.1.50/24)"): $ip"
  { [ -z "$gw" ] || valid_ipv4 "$gw"; }       || die "$(L "invalid gateway" "ungültiges Gateway"): $gw"
  [[ "$name" =~ ^[A-Za-z0-9-]{1,63}$ ]]       || die "$(L "invalid host name" "ungültiger Hostname"): $name"
  [ -x "$BIN" ] || install -m 755 "$(readlink -f "$0")" "$BIN"

  tmp=$(mktemp -d)
  ui_die(){ rm -rf "$tmp"; [ -n "${1:-}" ] && msg_error "$1"; [ -f "$UI_CONF" ] && echo -e "${TAB}$(L "Container $id is left for a look - remove it with: pve-autoupdate ui-remove" "Container $id bleibt zum Nachsehen stehen - entfernen mit: pve-autoupdate ui-remove")"; exit 1; }
  msg_info "$(L "Getting the web UI files" "Dateien der Weboberfläche werden geholt") ..."
  ui_get_files "$tmp" || ui_die "$(L "web UI files not found" "Dateien der Weboberfläche nicht gefunden")"
  msg_ok "$(L "Web UI files ready" "Dateien der Weboberfläche bereit")"
  msg_info "$(L "Getting the Debian template" "Debian-Vorlage wird geholt") ..."
  tmpl=$(ui_template "$tstorage") || ui_die "$(L "no Debian template available (pveam available --section system)" "keine Debian-Vorlage verfügbar (pveam available --section system)")"
  msg_ok "$(L "Template" "Vorlage"): ${tmpl#*/}"

  msg_info "$(L "Creating container" "Container wird angelegt") $id ..."
  net="name=eth0,bridge=$bridge,ip=$ip${gw:+,gw=$gw}${vlan:+,tag=$vlan}"
  pct create "$id" "$tmpl" --hostname "$name" --cores 1 --memory 256 --swap 256 --rootfs "$storage:2" \
    --net0 "$net" --unprivileged 1 --features nesting=1 --onboot 1 --timezone host --tags pve-autoupdate \
    --description "pve-autoupdate web UI - $REPO_URL" > "$tmp/create.log" 2>&1 \
    || ui_die "$(L "pct create failed" "pct create fehlgeschlagen"): $(tail -n 2 "$tmp/create.log")"
  printf 'UI_CTID=%s\n' "$id" > "$UI_CONF"
  pct start "$id" > /dev/null 2>&1 || ui_die "$(L "the container does not start" "der Container startet nicht")"
  log "web UI container $id created ($storage, $net)"
  msg_ok "$(L "Container $id created" "Container $id angelegt") ($name, $storage, $bridge)"

  msg_info "$(L "Waiting for the network" "Warte auf das Netzwerk") ..."
  for i in $(seq 60); do ctip=$(ui_ip "$id"); [ -n "$ctip" ] && break; sleep 2; done
  [ -n "$ctip" ] || ui_die "$(L "the container got no IP address" "der Container hat keine IP-Adresse bekommen")"
  for i in $(seq 30); do pct exec "$id" -- getent hosts deb.debian.org > /dev/null 2>&1 && break; sleep 2; done
  nodeip=$(ip -4 -o route get "$ctip" 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -n 1)
  [ -n "$nodeip" ] || nodeip="${NODE_IP[$SELF]:-}"
  valid_ipv4 "$nodeip" || ui_die "$(L "cannot tell which IP of this node the container reaches" "kann nicht erkennen, unter welcher IP der Container diesen Node erreicht")"
  msg_ok "$(L "Network" "Netzwerk"): $(L container Container) $ctip, Node $nodeip"

  msg_info "$(L "Installing packages (python3, ssh, openssl)" "Pakete werden installiert (python3, ssh, openssl)") ..."
  pct exec "$id" -- bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq python3 openssh-client openssl ca-certificates' > "$tmp/apt.log" 2>&1 \
    || ui_die "$(L "package installation failed" "Paketinstallation fehlgeschlagen"): $(tail -n 2 "$tmp/apt.log")"
  msg_ok "$(L "Packages installed" "Pakete installiert")"

  msg_info "$(L "Setting up the web UI" "Weboberfläche wird eingerichtet") ..."
  ui_push "$id" "$tmp" || ui_die "$(L "copying the files failed" "Kopieren der Dateien fehlgeschlagen")"
  pct exec "$id" -- bash -c "$UI_PREP" _ "$name" "$ctip" > "$tmp/prep.log" 2>&1 || ui_die "$(L "setup in the container failed" "Einrichtung im Container fehlgeschlagen"): $(tail -n 2 "$tmp/prep.log")"
  fp=$(api_fingerprint)
  hk=$(awk '{print $1" "$2}' /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null)
  [ -n "$fp" ] && [ -n "$hk" ] || ui_die "$(L "API certificate or SSH host key of this node not found" "API-Zertifikat oder SSH-Host-Schlüssel dieses Nodes nicht gefunden")"
  echo "$nodeip $hk" > "$tmp/known_hosts"
  printf '{\n  "listen": "0.0.0.0",\n  "port": %s,\n  "node": "%s",\n  "host": "%s",\n  "api_fingerprint": "%s"\n}\n' "$UI_PORT" "$SELF" "$nodeip" "$fp" > "$tmp/config.json"
  printf '%s\n' "$UI_UNIT_TXT" > "$tmp/unit"
  pct push "$id" "$tmp/known_hosts" "$UI_ETC/known_hosts" --perms 644 \
    && pct push "$id" "$tmp/config.json" "$UI_ETC/config.json" --perms 600 \
    && pct push "$id" "$tmp/unit" /etc/systemd/system/pve-autoupdate-ui.service --perms 644 \
    && pct exec "$id" -- chown -R pveau-ui: "$UI_ETC" || ui_die "$(L "copying the settings failed" "Kopieren der Einstellungen fehlgeschlagen")"
  pub=$(pct exec "$id" -- cat "$UI_ETC/id_ed25519.pub")
  cmd_pair "$pub"
  pct exec "$id" -- systemctl daemon-reload > /dev/null 2>&1
  pct exec "$id" -- systemctl enable --now pve-autoupdate-ui > /dev/null 2>&1 || ui_die "$(L "the web UI service does not start" "der Dienst der Weboberfläche startet nicht")"
  msg_ok "$(L "Web UI set up" "Weboberfläche eingerichtet")"

  # keep the UI container itself up to date too
  if [ -f "$CONF" ] && [ "$GUESTS" != all ] && ! in_list "$id" "$GUESTS"; then
    GUESTS="${GUESTS:+$GUESTS }$id"; write_config
    msg_ok "$(L "Container $id added to the automatic updates" "Container $id zu den automatischen Updates hinzugefügt")"
  fi

  msg_info "$(L "Waiting for the web UI" "Warte auf die Weboberfläche") ..."
  for i in $(seq "${PVE_AUTOUPDATE_UI_WAIT:-30}"); do
    curl -sk -o /dev/null --max-time 3 "https://$ctip:$UI_PORT/" && { up=1; break; }
    sleep 1
  done
  uifp=$(pct exec "$id" -- openssl x509 -in "$UI_ETC/ui.crt" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)
  rm -rf "$tmp"
  log "web UI ready: https://$ctip:$UI_PORT (container $id)"
  if [ "$up" = 1 ]; then msg_ok "$(L "Web UI ready" "Weboberfläche bereit"): https://$ctip:$UI_PORT"
  else msg_warn "$(L "The web UI does not answer yet - look with: pct exec $id -- journalctl -u pve-autoupdate-ui" "Die Weboberfläche antwortet noch nicht - nachsehen mit: pct exec $id -- journalctl -u pve-autoupdate-ui"): https://$ctip:$UI_PORT"; fi
  [ -n "${PVEAU_IN_SETUP:-}" ] || ui_box "$ctip" "${uifp:-}" "$([ "$ip" = dhcp ] && echo dhcp)"
  return 0
}

cmd_ui_update(){
  need_root; need_pve
  local id tmp; id=$(ui_ctid)
  ui_exists || die "$(L "no web UI container installed (pve-autoupdate ui-install)" "kein Weboberflächen-Container installiert (pve-autoupdate ui-install)")"
  tmp=$(mktemp -d)
  msg_info "$(L "Updating the web UI" "Weboberfläche wird aktualisiert") ..."
  if ! ui_get_files "$tmp" || ! ui_push "$id" "$tmp"; then rm -rf "$tmp"; die "$(L "web UI files could not be copied" "Dateien der Weboberfläche konnten nicht kopiert werden")"; fi
  rm -rf "$tmp"
  pct exec "$id" -- systemctl restart pve-autoupdate-ui > /dev/null 2>&1 || die "$(L "the web UI service does not start" "der Dienst der Weboberfläche startet nicht")"
  log "web UI in container $id updated"
  msg_ok "$(L "Web UI updated" "Weboberfläche aktualisiert")${id:+ ($(L container Container) $id)}"
}

cmd_ui_remove(){
  need_root; need_pve
  local id; id=$(ui_ctid)
  # only ever destroy a container this script created
  if ui_exists && ! grep -qE '^tags:.*pve-autoupdate' <<< "$(pct config "$id" 2>/dev/null)"; then
    die "$(L "container $id is not tagged pve-autoupdate - not touching it" "Container $id hat nicht das Tag pve-autoupdate - wird nicht angefasst")"
  fi
  cmd_unpair
  if ui_exists; then
    msg_info "$(L "Removing container" "Container wird entfernt") $id ..."
    pct stop "$id" > /dev/null 2>&1
    pct destroy "$id" --purge > /dev/null 2>&1 || die "$(L "pct destroy $id failed" "pct destroy $id fehlgeschlagen")"
    log "web UI container $id removed"
  fi
  rm -f "$UI_CONF"
  msg_ok "$(L "Web UI removed" "Weboberfläche entfernt")"
}

# ============================================================================
#  Setup wizard
# ============================================================================
wt(){ whiptail --backtitle "$BACKTITLE" "$@" 3>&1 1>&2 2>&3; }
abort(){ clear; echo "$(L "Cancelled - nothing saved." "Abgebrochen - nichts gespeichert.")"; exit 1; }
yn(){ # title text default(1/0) [height]
  local d=""; [ "$3" = 1 ] || d="--defaultno"
  whiptail --backtitle "$BACKTITLE" --title "$1" $d --yes-button "$(L Yes Ja)" --no-button "$(L No Nein)" --yesno "$2" "${4:-14}" 78 >&2
  case $? in 0) echo 1 ;; 1) echo 0 ;; *) abort ;; esac
}
choose_language(){
  local l
  l=$(whiptail --backtitle "$BACKTITLE" --title "Language / Sprache" --default-item "$UI_LANG" \
      --menu "\nChoose your language / Sprache wählen:" 13 50 2 en "English" de "Deutsch" 3>&1 1>&2 2>&3) || return 1
  UI_LANG="$l"
}

cmd_setup(){
  need_root; need_pve
  load_config
  if [ "${1:-}" = --apply ]; then install_units; msg_ok "$(L "Schedule applied" "Zeitplan übernommen"): $(describe_schedule)"; return; fi
  need_whiptail
  load_nodes
  local guests; guests=$(list_guests | awk -F'|' '$6!=1')
  local nlxc nvm n_nodes intro
  nlxc=$(awk -F'|' '$2=="lxc"' <<< "$guests" | grep -c .); nvm=$(awk -F'|' '$2=="qemu"' <<< "$guests" | grep -c .)
  n_nodes=$(wc -w <<< "$NODES")
  [ -f "$CONF" ] || TITLE="${CLUSTER_NAME:-$SELF}"
  local ok_btn=(--ok-button "$(L Next Weiter)" --cancel-button "$(L Cancel Abbrechen)")

  if [ -n "$CLUSTER_NAME" ]; then intro="$(L "Detected: cluster '$CLUSTER_NAME' with $n_nodes nodes ($NODES)." "Erkannt: Cluster '$CLUSTER_NAME' mit $n_nodes Nodes ($NODES).")"
  else intro="$(L "Detected: single node '$SELF' (no cluster)." "Erkannt: einzelner Node '$SELF' (kein Cluster).")"; fi
  intro="$intro\n$(L "$nlxc containers and $nvm VMs." "$nlxc Container und $nvm VMs.")\n\n$(L \
"The wizard asks:\n  1. which containers/VMs are updated\n  2. whether nodes and apps are included\n  3. safety net (snapshots) and reboots\n  4. how often\n  5. whether and where to send a mail\n\nThe schedule runs on this node ($SELF)." \
"Der Assistent fragt:\n  1. welche Container/VMs aktualisiert werden\n  2. ob Nodes und Anwendungen dazugehören\n  3. Sicherheitsnetz (Snapshots) und Neustarts\n  4. wie häufig\n  5. ob und wohin eine Mail geht\n\nDer Zeitplan läuft auf diesem Node ($SELF).")"
  wt --title "$(L "Set up pve-autoupdate" "pve-autoupdate einrichten")" --ok-button "$(L Next Weiter)" --msgbox "$intro" 20 74 || abort

  # ---- 1. guests
  local mode items=() id type name node status tmpl on sel
  if [ "$GUESTS" = all ]; then mode=all; elif [ -z "$GUESTS" ]; then mode=none; else mode=select; fi
  mode=$(wt --title "1/5  $(L "Containers & VMs" "Container & VMs")" "${ok_btn[@]}" --default-item "$mode" \
    --menu "$(L "Which guests should be updated automatically?" "Welche Gäste sollen automatisch aktualisiert werden?")" 14 74 3 \
    all    "$(L "All containers - new ones are added automatically" "Alle Container - neue kommen automatisch dazu")" \
    select "$(L "Only selected containers/VMs" "Nur ausgewählte Container/VMs")" \
    none   "$(L "No guests, only the nodes themselves" "Keine Gäste, nur die Nodes selbst")") || abort
  case "$mode" in
    all)
      GUESTS=all
      INCLUDE_VMS=$(yn "VMs" "$(L "Update VMs too?\n\nWorks for Linux and Windows VMs with the QEMU guest agent installed and enabled. VMs without agent are skipped silently." "Auch VMs aktualisieren?\n\nGeht bei Linux- und Windows-VMs mit installiertem und aktiviertem QEMU-Guest-Agent. VMs ohne Agent werden still übersprungen.")" "$INCLUDE_VMS")
      items=()
      while IFS='|' read -r id type name node status tmpl; do
        [ -n "$id" ] || continue
        [ "$type" = qemu ] && [ "$INCLUDE_VMS" != 1 ] && continue
        on=OFF; in_list "$id" "$EXCLUDE" && on=ON
        items+=("$id" "$(printf '%-22s %-4s @%-10s %s' "${name:0:22}" "$([ "$type" = lxc ] && echo CT || echo VM)" "$node" "$status")" "$on")
      done <<< "$guests"
      if [ ${#items[@]} -gt 0 ]; then
        sel=$(wt --title "$(L Exceptions Ausnahmen)" "${ok_btn[@]}" --checklist "$(L "Do NOT update these guests (space = select):" "Diese Gäste NICHT aktualisieren (Leertaste = markieren):")" 20 78 12 "${items[@]}") || abort
        EXCLUDE=$(tr -d '"' <<< "$sel")
      fi ;;
    select)
      items=()
      while IFS='|' read -r id type name node status tmpl; do
        [ -n "$id" ] || continue
        on=OFF; { [ "$GUESTS" = all ] && [ "$type" = lxc ]; } && on=ON; in_list "$id" "$GUESTS" && on=ON
        items+=("$id" "$(printf '%-22s %-4s @%-10s %s' "${name:0:22}" "$([ "$type" = lxc ] && echo CT || echo "VM*")" "$node" "$status")" "$on")
      done <<< "$guests"
      if [ ${#items[@]} -eq 0 ]; then
        wt --msgbox "$(L "No containers or VMs found - only the nodes will be updated." "Keine Container oder VMs gefunden - es werden nur die Nodes aktualisiert.")" 8 70; GUESTS=""
      else
        sel=$(wt --title "$(L Selection Auswahl)" "${ok_btn[@]}" --checklist "$(L "Which guests should be updated? (space = select)\nVM* = needs the QEMU guest agent (Linux or Windows)" "Welche Gäste aktualisieren? (Leertaste = markieren)\nVM* = braucht den QEMU-Guest-Agent (Linux oder Windows)")" 22 78 12 "${items[@]}") || abort
        GUESTS=$(tr -d '"' <<< "$sel")
      fi
      EXCLUDE=""; INCLUDE_VMS=0 ;;
    none) GUESTS=""; EXCLUDE="" ;;
  esac

  # ---- 2. nodes and apps
  UPDATE_HOSTS=$(yn "2/5  Nodes" "$(L "Update the Proxmox nodes themselves too?\n(apt dist-upgrade on $NODES)\n\nWhether they reboot afterwards is asked next." "Sollen auch die Proxmox-Nodes selbst aktualisiert werden?\n(apt dist-upgrade auf $NODES)\n\nOb sie danach neu starten, kommt gleich.")" "$UPDATE_HOSTS")
  UPDATE_SERVICES=$(yn "2/5  $(L Apps Anwendungen)" "$(L "Update apps inside the guests too?\n\n - Docker Compose stacks (pull + up -d)\n - auto-detected: AdGuard Home, Forgejo, Uptime Kuma, Beszel\n - own services from $SVC_DIR/*.conf\n\nThe package manager (apt, apk, dnf ...) always runs." "Auch Anwendungen in den Gästen aktualisieren?\n\n - Docker-Compose-Stacks (pull + up -d)\n - automatisch erkannt: AdGuard Home, Forgejo, Uptime Kuma, Beszel\n - eigene Dienste aus $SVC_DIR/*.conf\n\nDer Paketmanager (apt, apk, dnf ...) läuft in jedem Fall.")" "$UPDATE_SERVICES")

  if [ "$nvm" -gt 0 ] && { [ "$INCLUDE_VMS" = 1 ] || [ "$GUESTS" != all ]; } && [ -n "$GUESTS" ]; then
    UPDATE_WINDOWS=$(yn "2/5  Windows" "$(L "Update Windows VMs with Windows Update?\n\n - security and quality updates (no feature upgrades, no drivers)\n - the VM reboots to finish them and is checked afterwards\n - rollback to the snapshot if it does not come back or services fail\n\nNeeds the QEMU guest agent (virtio-win). Can take 30-60 min per VM." "Windows-VMs per Windows Update aktualisieren?\n\n - Sicherheits- und Qualitätsupdates (keine Funktionsupgrades, keine Treiber)\n - die VM startet zum Abschließen neu und wird danach geprüft\n - Rollback auf den Snapshot, wenn sie nicht zurückkommt oder Dienste ausfallen\n\nBraucht den QEMU-Guest-Agent (virtio-win). Kann 30-60 Min. pro VM dauern.")" "$UPDATE_WINDOWS" 18)
  fi
  # ---- 3. safety net and reboots
  SNAPSHOT=$(wt --title "3/5  $(L "Safety net" Sicherheitsnetz)" "${ok_btn[@]}" --default-item "$SNAPSHOT" --menu "$(L "Take a snapshot before every update? If the health check fails afterwards, the guest is rolled back automatically.\n\n(Snapshots need LVM-thin, ZFS, Ceph or similar - not 'Directory'.)" "Vor jedem Update einen Snapshot anlegen? Schlägt der Health-Check danach fehl, wird automatisch auf den Snapshot zurückgesetzt.\n\n(Snapshots brauchen LVM-Thin, ZFS, Ceph o.ä. - nicht 'Directory'.)")" 17 76 3 \
    optional "$(L "Snapshot if possible, otherwise update without a net" "Snapshot wenn möglich, sonst ohne Netz aktualisieren")" \
    required "$(L "Skip the guest without a snapshot (safest choice)" "Ohne Snapshot wird der Gast übersprungen (sicherste Wahl)")" \
    off      "$(L "No snapshots, no rollback" "Keine Snapshots, kein Rollback")") || abort
  local rsel rg=OFF rh=OFF; [ "$REBOOT_GUESTS" = 1 ] && rg=ON; [ "$REBOOT_HOSTS" = 1 ] && rh=ON
  rsel=$(wt --title "3/5  $(L Reboots Neustarts)" "${ok_btn[@]}" --checklist "$(L "Reboot automatically when an update needs it?" "Automatisch neu starten, wenn ein Update es verlangt?")" 13 78 2 \
    guests "$(L "Containers/VMs (e.g. after a libc update)" "Container/VMs (z.B. nach libc-Update)")" "$rg" \
    hosts  "$(L "Nodes (kernel update) - one after another in a cluster" "Nodes (Kernel-Update) - im Cluster einer nach dem anderen")" "$rh") || abort
  REBOOT_GUESTS=0; REBOOT_HOSTS=0
  in_list guests "$(tr -d '"' <<< "$rsel")" && REBOOT_GUESTS=1
  in_list hosts  "$(tr -d '"' <<< "$rsel")" && REBOOT_HOSTS=1

  # ---- 4. schedule
  local freq day="Mon" hm="03:00" cal d win
  [[ "$SCHEDULE" =~ ([0-9]{2}:[0-9]{2}) ]] && hm="${BASH_REMATCH[1]}"
  [[ "$SCHEDULE" =~ ^([A-Z][a-z]{2})\  ]] && day="${BASH_REMATCH[1]}"
  freq=weekly
  [[ "$SCHEDULE" =~ ^\*-\*-\* ]] && freq=daily
  [[ "$SCHEDULE" =~ 01\.\.07 ]] && freq=monthly
  freq=$(wt --title "4/5  $(L "How often?" "Wie häufig?")" "${ok_btn[@]}" --default-item "$freq" --menu "$(L "When should the updates run?" "Wann sollen die Updates laufen?")" 14 74 4 \
    daily   "$(L Daily Täglich)" \
    weekly  "$(L "Weekly (choose the weekday)" "Wöchentlich (Wochentag wählen)")" \
    monthly "$(L "Monthly (first weekday of the month)" "Monatlich (erster Wochentag im Monat)")" \
    custom  "$(L "Own systemd schedule (OnCalendar)" "Eigener systemd-Zeitplan (OnCalendar)")") || abort
  if [ "$freq" = custom ]; then
    while :; do
      cal=$(wt --title "$(L "Own schedule" "Eigener Zeitplan")" "${ok_btn[@]}" --inputbox "$(L "systemd OnCalendar, e.g. 'Sat *-*-* 04:30:00' or 'Mon,Thu *-*-* 03:00:00':" "systemd OnCalendar, z.B. 'Sat *-*-* 04:30:00' oder 'Mon,Thu *-*-* 03:00:00':")" 10 74 "$SCHEDULE") || abort
      systemd-analyze calendar "$cal" >/dev/null 2>&1 && break
      wt --msgbox "$(L "'$cal' is not a valid schedule." "'$cal' ist kein gültiger Zeitplan.")" 8 60
    done
    SCHEDULE="$cal"
  else
    if [ "$freq" != daily ]; then
      items=(); for d in Mon Tue Wed Thu Fri Sat Sun; do items+=("$d" "$(weekday "$d")"); done
      day=$(wt --title "$(L Weekday Wochentag)" "${ok_btn[@]}" --default-item "$day" --menu "$(L "Which day?" "An welchem Tag?")" 16 50 7 "${items[@]}") || abort
    fi
    win="${UPDATE_WINDOW:-$hm}"
    while :; do
      win=$(wt --title "$(L "Time window" "Zeitfenster")" "${ok_btn[@]}" --inputbox "$(L \
"From when to when may updates run? (24h)\n\n  02:00-05:00  updates start at 02:00; whatever is not done by 05:00 waits for the next run, reboots too\n  03:00        start at 03:00, no end\n\nBest at night and not during the backup:" \
"Von wann bis wann dürfen Updates laufen? (24h)\n\n  02:00-05:00  Start um 02:00; was um 05:00 nicht fertig ist, wartet auf den nächsten Lauf, Neustarts auch\n  03:00        Start um 03:00, ohne Ende\n\nAm besten nachts und nicht während des Backups:")" 16 78 "$win") || abort
      if [[ "$win" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then hm="$win"; UPDATE_WINDOW=""; break; fi
      if valid_window "$win"; then hm="${win%-*}"; UPDATE_WINDOW="$win"; break; fi
      wt --msgbox "$(L "Please use HH:MM-HH:MM or HH:MM, e.g. 02:00-05:00" "Bitte als HH:MM-HH:MM oder HH:MM, z.B. 02:00-05:00")" 8 60
    done
    case "$freq" in
      daily)   SCHEDULE="*-*-* $hm:00" ;;
      weekly)  SCHEDULE="$day *-*-* $hm:00" ;;
      monthly) SCHEDULE="$day *-*-01..07 $hm:00" ;;
    esac
  fi

  # ---- 5. notification
  NOTIFY=$(wt --title "5/5  $(L Notification Benachrichtigung)" "${ok_btn[@]}" --default-item "$NOTIFY" --menu "$(L "When should a mail be sent?" "Wann soll eine Mail kommen?")" 14 74 4 \
    errors  "$(L "Only when something went wrong (recommended)" "Nur wenn etwas schiefgelaufen ist (empfohlen)")" \
    changes "$(L "On problems and when something was updated" "Bei Problemen und wenn etwas aktualisiert wurde")" \
    always  "$(L "After every run" "Nach jedem Lauf")" \
    never   "$(L Never Nie)") || abort
  if [ "$NOTIFY" != never ]; then
    while :; do
      MAIL_TO=$(wt --title "$(L Recipient Empfänger)" "${ok_btn[@]}" --inputbox "$(L "E-mail address (separate several with commas).\nLeave empty to set up mail later." "E-Mail-Adresse (mehrere mit Komma trennen).\nLeer lassen = Mail später einrichten.")" 11 74 "$MAIL_TO") || abort
      [ -z "$MAIL_TO" ] && break
      [[ "$MAIL_TO" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+ ]] && break
      wt --msgbox "$(L "That does not look like an e-mail address." "Das sieht nicht nach einer Mail-Adresse aus.")" 8 50
    done
    if [ -z "$MAIL_TO" ]; then
      NOTIFY=never
      wt --title "$(L Notification Benachrichtigung)" --msgbox "$(L "No address entered - notifications are off for now.\n\nSet them up later with: pve-autoupdate setup" "Keine Adresse eingetragen - die Benachrichtigung ist vorerst aus.\n\nSpäter einrichten mit: pve-autoupdate setup")" 10 64
    fi
  fi
  if [ "$NOTIFY" != never ]; then
    MAIL_TRANSPORT=$(wt --title "$(L Transport Versand)" "${ok_btn[@]}" --default-item "$MAIL_TRANSPORT" --menu "$(L "How should the mail be sent?" "Wie soll die Mail verschickt werden?")" 13 76 2 \
      system "$(L "Proxmox mail system (postfix) - like the PVE notifications" "Proxmox-Mailsystem (postfix) - wie die PVE-Benachrichtigungen")" \
      smtp   "$(L "Own SMTP server (e.g. Gmail with app password)" "Eigener SMTP-Server (z.B. Gmail mit App-Passwort)")") || abort
    if [ "$MAIL_TRANSPORT" = smtp ]; then
      SMTP_HOST=$(wt --title "SMTP" "${ok_btn[@]}" --inputbox "$(L "SMTP server:" "SMTP-Server:")" 9 74 "${SMTP_HOST:-smtp.gmail.com}") || abort
      SMTP_SECURITY=$(wt --title "SMTP" "${ok_btn[@]}" --default-item "$SMTP_SECURITY" --menu "$(L Encryption: Verschlüsselung:)" 12 60 3 \
        starttls "$(L "STARTTLS (usually port 587)" "STARTTLS (meist Port 587)")" \
        ssl      "$(L "SSL/TLS (usually port 465)" "SSL/TLS (meist Port 465)")" \
        none     "$(L "none (port 25, LAN only)" "keine (Port 25, nur im LAN)")") || abort
      local defport=587; [ "$SMTP_SECURITY" = ssl ] && defport=465; [ "$SMTP_SECURITY" = none ] && defport=25
      SMTP_PORT=$(wt --title "SMTP" "${ok_btn[@]}" --inputbox "Port:" 9 40 "$defport") || abort
      SMTP_USER=$(wt --title "SMTP" "${ok_btn[@]}" --inputbox "$(L "User name (empty = no login):" "Benutzername (leer = ohne Anmeldung):")" 9 74 "${SMTP_USER:-$MAIL_TO}") || abort
      if [ -n "$SMTP_USER" ]; then
        local pw keep=""
        [ -n "$SMTP_PASS" ] && keep=" $(L "(empty = keep current)" "(leer = bisheriges behalten)")"
        pw=$(wt --title "SMTP" "${ok_btn[@]}" --passwordbox "$(L "Password or app password" "Passwort bzw. App-Passwort")$keep:" 9 74) || abort
        [ -n "$pw" ] && SMTP_PASS="$pw"
      fi
    fi
    MAIL_FROM=$(wt --title "$(L Sender Absender)" "${ok_btn[@]}" --inputbox "$(L "Sender address (empty = automatic):" "Absenderadresse (leer = automatisch):")" 9 74 "$MAIL_FROM") || abort
    TITLE=$(wt --title "Name" "${ok_btn[@]}" --inputbox "$(L "Name in the subject, e.g. [$TITLE] Updates: ..." "Name im Betreff, z.B. [$TITLE] Updates: ...")" 9 74 "$TITLE") || abort
  fi

  # ---- summary
  wt --title "$(L Summary Zusammenfassung)" --yes-button "$(L Save Speichern)" --no-button "$(L Cancel Abbrechen)" --yesno "$(L "Guests:          " "Gäste:           ")$(guests_text)
$(L "Update nodes:    " "Nodes updaten:   ")$(yesno_txt "$UPDATE_HOSTS")
$(L "Apps:            " "Anwendungen:     ")$(yesno_txt "$UPDATE_SERVICES")
Snapshots:       $SNAPSHOT
$(L "Reboot guests:   " "Neustart Gäste:  ")$(yesno_txt "$REBOOT_GUESTS")
$(L "Reboot nodes:    " "Neustart Nodes:  ")$(yesno_txt "$REBOOT_HOSTS")
$(L "Schedule:        " "Zeitplan:        ")$(describe_schedule)
Mail:            $(notify_text)

$(L "Save and activate?" "Speichern und aktivieren?")" 20 78 || abort

  header_info
  [ -x "$BIN" ] || install_self
  write_example
  msg_info "$(L "Saving settings" "Einstellungen werden gespeichert") ..."
  write_config
  install_units
  msg_ok "$(L "Saved in" "Gespeichert in") $CONF"
  msg_ok "$(L "Schedule active" "Zeitplan aktiv"): $(describe_schedule)  ($(L next nächster): $(next_run))"

  if [ "$NOTIFY" != never ] && [ "$(yn "$(L "Test mail" Testmail)" "$(L "Send a test mail to $MAIL_TO now?" "Jetzt eine Testmail an $MAIL_TO schicken?")" 1)" = 1 ]; then
    ( cmd_test_mail ) || true
  fi
  if [ "$(yn "$(L "Dry run" Testlauf)" "$(L "Do a dry run now?\n\nNothing is changed - it only checks what there is to update and whether all guests are reachable." "Jetzt einen Testlauf machen?\n\nEs wird nichts verändert - nur geprüft, was es zu aktualisieren gäbe und ob alle Gäste erreichbar sind.")" 1)" = 1 ]; then
    ( cmd_run --dry-run ) || true
  fi
  # web UI: the wizard of ui-install starts with its own yes/no
  ui_exists || ( PVEAU_IN_SETUP=1; cmd_ui_install ) || true
  echo
  msg_ok "$(L "Done. Run 'pve-autoupdate' again any time to open the menu." "Fertig. 'pve-autoupdate' jederzeit erneut aufrufen, um das Menü zu öffnen.")"
  has_donate && echo -e "${TAB}${MUT}♥ $(L "If pve-autoupdate saves you time, I'd appreciate your support on Liberapay:" "Wenn dir pve-autoupdate Zeit spart, freue ich mich über Unterstützung auf Liberapay:")${CL} ${AC}$DONATE_URL${CL}"
  ui_box
  return 0
}

# ============================================================================
#  Menu (running `pve-autoupdate` or the one-liner again)
# ============================================================================
show_about(){
  local t
  t="pve-autoupdate $VERSION\n\n$(L "Unattended updates for Proxmox VE - containers, VMs, apps and nodes, with snapshot rollback and mail reports." "Automatische Updates für Proxmox VE - Container, VMs, Anwendungen und Nodes, mit Snapshot-Rollback und Mail-Bericht.")\n\n$(L "Made by" "Gemacht von") $AUTHOR · ${WEBSITE#https://}"
  has_repo && t="$t\n$REPO_URL"
  has_donate && t="$t\n\n♥ $(DONATE_TXT)\n$DONATE_URL"
  t="$t\n\n$(L "License" "Lizenz"): MIT"
  wt --title "$(L "About" "Über")" --msgbox "$t" 20 74
}

show_log(){
  local f; f=$(mktemp)
  if [ -f "$LOGF" ]; then tail -n 400 "$LOGF" > "$f"; else L "No log yet." "Noch kein Log vorhanden." > "$f"; fi
  whiptail --backtitle "$BACKTITLE" --title "$LOGF" --scrolltext --textbox "$f" 30 100
  rm -f "$f"
}

main_menu(){
  local c
  while :; do
    load_config
    header_info
    c=$(wt --title "pve-autoupdate $VERSION" --ok-button "$(L Select Auswählen)" --cancel-button "$(L Exit Beenden)" \
      --menu "$(L "Next run" "Nächster Lauf"): $(next_run)\n$(L "Schedule" "Zeitplan"): $(describe_schedule)" 22 74 11 \
      run      "$(L "Run updates now" "Updates jetzt ausführen")" \
      dryrun   "$(L "Dry run (check only, change nothing)" "Testlauf (nur prüfen, nichts ändern)")" \
      setup    "$(L "Change settings" "Einstellungen ändern")" \
      status   "$(L "Show status" "Status anzeigen")" \
      log      "$(L "View log" "Log ansehen")" \
      testmail "$(L "Send test mail" "Testmail senden")" \
      webui    "$(L "Web UI" "Weboberfläche")" \
      update   "$(L "Update pve-autoupdate" "pve-autoupdate aktualisieren")" \
      language "Language / Sprache" \
      about    "$(L "About & support" "Über & Unterstützen") ♥" \
      remove   "$(L "Uninstall" "Deinstallieren")") || { clear; exit 0; }
    case "$c" in
      run)
        if [ "$(yn "$(L "Run updates" "Updates ausführen")" "$(L "Update all selected guests and nodes now?\n\nGuests: $(guests_text)\nSnapshots: $SNAPSHOT\nReboots: guests $(yesno_txt "$REBOOT_GUESTS"), nodes $(yesno_txt "$REBOOT_HOSTS")" "Jetzt alle ausgewählten Gäste und Nodes aktualisieren?\n\nGäste: $(guests_text)\nSnapshots: $SNAPSHOT\nNeustarts: Gäste $(yesno_txt "$REBOOT_GUESTS"), Nodes $(yesno_txt "$REBOOT_HOSTS")")" 0)" = 1 ]; then
          header_info; ( cmd_run ) || true; pause
        fi ;;
      dryrun)   header_info; ( cmd_run --dry-run ) || true; pause ;;
      setup)    ( cmd_setup ) || true; pause ;;
      status)   header_info; ( cmd_status ); pause ;;
      log)      show_log ;;
      testmail) header_info; ( cmd_test_mail ) || true; pause ;;
      webui)    ui_menu ;;
      update)   header_info; ( cmd_self_update ) || true; pause; exec "$BIN" ;;
      language) choose_language && write_config ;;
      about)    show_about ;;
      remove)
        if [ "$(yn "$(L Uninstall Deinstallieren)" "$(L "Remove pve-autoupdate (timer and program)?" "pve-autoupdate entfernen (Timer und Programm)?")" 0)" = 1 ]; then
          header_info
          if [ "$(yn "$(L Uninstall Deinstallieren)" "$(L "Also delete settings and log?" "Auch Einstellungen und Log löschen?")" 0)" = 1 ]; then cmd_uninstall --purge; else cmd_uninstall; fi
          exit 0
        fi ;;
    esac
  done
}

ui_menu(){
  local c url
  if ! ui_exists; then header_info; ( cmd_ui_install ) || true; pause; return; fi
  url=$(ui_url)
  c=$(wt --title "$(L "Web UI" "Weboberfläche")" --menu "$(L "Container" "Container") $(ui_ctid)\n${url:-$(L "address unknown (container stopped?)" "Adresse unbekannt (Container gestoppt?)")}" 14 70 3 \
      update "$(L "Update the web UI" "Weboberfläche aktualisieren")" \
      remove "$(L "Remove the web UI container" "Weboberflächen-Container entfernen")" \
      back   "$(L "Back" "Zurück")") || return
  case "$c" in
    update) header_info; ( cmd_ui_update ) || true; pause ;;
    remove)
      if [ "$(yn "$(L "Web UI" "Weboberfläche")" "$(L "Remove container $(ui_ctid) with the web UI?" "Container $(ui_ctid) mit der Weboberfläche entfernen?")" 0)" = 1 ]; then
        header_info; ( cmd_ui_remove ) || true; pause
      fi ;;
  esac
}

# first start (one-liner) or menu
cmd_interactive(){
  need_root; need_pve; need_whiptail
  load_config
  if [ -f "$CONF" ] && [ -x "$BIN" ]; then main_menu; return; fi
  header_info
  [ -n "${PVE_AUTOUPDATE_LANG:-}" ] || choose_language || exit 0
  header_info
  wt --title "$(L "Welcome" "Willkommen")" --yes-button "$(L "Install" "Installieren")" --no-button "$(L Cancel Abbrechen)" --yesno "$(L \
"pve-autoupdate keeps your Proxmox node or cluster up to date by itself.\n\n  ✔  containers and VMs (Linux and Windows)\n  ✔  apps inside the guests (Docker, AdGuard, Forgejo ...)\n  ✔  the Proxmox nodes themselves\n\nSafe by design:\n  ▸  a snapshot before every update\n  ▸  health check, automatic rollback on failure\n  ▸  a mail report when something goes wrong\n\nNext, the program is installed on this node and the wizard\nasks five short questions.\n\nInstall now?" \
"pve-autoupdate hält deinen Proxmox-Node oder -Cluster von selbst aktuell.\n\n  ✔  Container und VMs (Linux und Windows)\n  ✔  Anwendungen in den Gästen (Docker, AdGuard, Forgejo ...)\n  ✔  die Proxmox-Nodes selbst\n\nSicher gebaut:\n  ▸  ein Snapshot vor jedem Update\n  ▸  Health-Check, bei Fehlern automatischer Rollback\n  ▸  ein Mail-Bericht, wenn etwas schiefgeht\n\nAls Nächstes wird das Programm auf diesem Node installiert, und\nder Assistent stellt fünf kurze Fragen.\n\nJetzt installieren?")" 25 72 || { clear; exit 0; }
  install_self
  cmd_setup
}

usage(){
  cat <<EOF
pve-autoupdate $VERSION by $AUTHOR - $(L "unattended updates for Proxmox VE (node or cluster)" "automatische Updates für Proxmox VE (Node oder Cluster)")

  pve-autoupdate                 $(L "menu (first start: install + setup)" "Menü (beim ersten Start: Installation + Einrichtung)")
  pve-autoupdate setup           $(L "change settings (wizard)" "Einstellungen ändern (Assistent)")
  pve-autoupdate setup --apply   $(L "apply the schedule after editing the config by hand" "Zeitplan nach Hand-Änderung der Konfiguration übernehmen")
  pve-autoupdate run             $(L "run updates now" "Updates jetzt ausführen")
  pve-autoupdate run --dry-run   $(L "check only, change nothing (with --mail: mail the report)" "nur prüfen, nichts ändern (mit --mail: Bericht mailen)")
  pve-autoupdate run --only 101,node:pve1   $(L "only these guests / nodes (--reboot, --no-reboot)" "nur diese Gäste / Nodes (--reboot, --no-reboot)")
  pve-autoupdate status          $(L "settings, next run, last log lines" "Einstellungen, nächster Lauf, letzte Log-Zeilen")
  pve-autoupdate test-mail       $(L "send a test mail" "Testmail senden")
  pve-autoupdate self-update     $(L "update pve-autoupdate itself (diff + SHA256)" "pve-autoupdate selbst aktualisieren (Diff + SHA256)")
  pve-autoupdate uninstall       $(L "remove timer and program (--purge: settings and web UI too)" "Timer und Programm entfernen (--purge: auch Einstellungen und Weboberfläche)")

  pve-autoupdate ui-install      $(L "create the web UI container (wizard; or --yes with" "Weboberflächen-Container anlegen (Assistent; oder --yes mit")
                                 --ctid --storage --bridge --vlan --ip dhcp|CIDR --gw --hostname)
  pve-autoupdate ui-update       $(L "copy the current web UI into the container" "aktuelle Weboberfläche in den Container kopieren")
  pve-autoupdate ui-remove       $(L "remove the web UI container and its access" "Weboberflächen-Container und seinen Zugang entfernen")

$(L "For the web UI container (JSON):" "Für den Weboberflächen-Container (JSON):") inventory, history, events, start, config set, log, api-fingerprint
  pve-autoupdate pair "<key>"    $(L "let the web UI in - its SSH key may only run pve-autoupdate" "Weboberfläche zulassen - ihr SSH-Schlüssel darf nur pve-autoupdate ausführen")
  pve-autoupdate unpair          $(L "remove that access again" "diesen Zugang wieder entfernen")

$(L "Config" "Konfiguration"): $CONF
$(L "Own services" "Eigene Dienste"): $SVC_DIR/*.conf
Log: $LOGF
EOF
  has_repo && echo "$REPO_URL"
  has_donate && echo "♥ Liberapay: $DONATE_URL"
  return 0
}

dispatch(){
  case "${1:-}" in
    "")          cmd_interactive ;;
    install)     need_root; need_pve; need_whiptail; load_config; [ -f "$CONF" ] || { choose_language || exit 0; }; install_self; cmd_setup ;;
    setup)       shift; cmd_setup "$@" ;;
    run)         shift; cmd_run "$@" ;;
    status)      cmd_status ;;
    test-mail)   cmd_test_mail ;;
    postcheck)   shift; need_root; cmd_postcheck "$@" ;;
    self-update|update) shift; cmd_self_update "$@" ;;
    uninstall)   shift; cmd_uninstall "$@" ;;
    version|--version|-v) echo "pve-autoupdate $VERSION" ;;
    inventory)   cmd_inventory ;;
    history)     shift; cmd_history "$@" ;;
    events)      shift; cmd_events "$@" ;;
    start)       shift; cmd_start "$@" ;;
    config)      shift; cmd_config "$@" ;;
    log)         shift; cmd_log "$@" ;;
    pair)        shift; cmd_pair "$@" ;;
    unpair)      cmd_unpair ;;
    api-fingerprint) cmd_api_fingerprint ;;
    ui-install)  shift; cmd_ui_install "$@" ;;
    ui-update)   cmd_ui_update ;;
    ui-remove)   cmd_ui_remove ;;
    remote)      cmd_remote ;;
    help|-h|--help) usage ;;
    *)           usage; exit 1 ;;
  esac
}

[ -r "$CONF" ] && load_config
dispatch "$@"
