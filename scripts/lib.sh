# Shared helpers for the host-side scripts (sourced, not run).
# Works on macOS and Linux with bash, adb and curl.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE=/data/local/tmp/albumframe-install     # temporary folder on the frame

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. $2"; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# pick_device [ip[:port]] -> sets $ADB ("adb -s SERIAL")
pick_device() {
  need adb "Install Android platform-tools: https://developer.android.com/tools/releases/platform-tools (macOS: brew install android-platform-tools)"
  local target="$1" serial
  if [ -n "$target" ]; then
    case "$target" in *:*) ;; *) target="$target:5555" ;; esac
    adb connect "$target" >/dev/null 2>&1 || true
    serial="$target"
  else
    local list; list=$(adb devices | awk 'NR>1 && $2=="device"{print $1}')
    [ -n "$list" ] || die "No frame found. Connect it (see docs/1-enable-adb.md) or pass --device <frame-ip>."
    [ "$(echo "$list" | wc -l | tr -d ' ')" = 1 ] || die "More than one device connected; pass --device <serial or ip>. Found: $(echo $list)"
    serial="$list"
  fi
  local state; state=$(adb -s "$serial" get-state 2>&1 || true)
  case "$state" in
    device) ;;
    *unauthorized*) die "The frame is asking 'Allow USB debugging?'. Tap Allow on the frame (tick 'Always allow'), then run this again." ;;
    *) die "Cannot reach the frame at $serial ($state)." ;;
  esac
  ADB="adb -s $serial"
  SERIAL="$serial"
}

# run a command on the frame as root
rsh() { $ADB shell su 0 "$@"; }

check_root() {
  rsh id 2>/dev/null | grep -q 'uid=0' || die "No root access on the frame ('su 0' failed). This project needs the preinstalled su found on Frameo frames like the REUMAR NZ-DP1002."
}

wait_for_boot() {
  local i=0
  say "Waiting for the frame to start again (up to 3 minutes)..."
  while [ $i -lt 90 ]; do
    case "$SERIAL" in *:*) adb connect "$SERIAL" >/dev/null 2>&1 || true ;; esac
    [ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && return 0
    sleep 2; i=$((i+1))
  done
  return 1
}
