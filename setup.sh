#!/bin/bash
# X836 setup — idempotent installer for the fixes in this repo.
#
# Usage:
#   sudo ./setup.sh            # install
#   sudo ./setup.sh --dry-run  # show what would happen, change nothing
#   sudo ./setup.sh --help
#
# What this script does (safe, reversible):
#   1. Detects the device (warns if not an X836 / J4105)
#   2. Copies scripts to /usr/local/bin/
#   3. Installs configs under /etc/ (udev hwdb, modprobe blacklist,
#      logind lid policy, systemd sleep disable)
#   4. Creates systemd services: fix-audio, fix-rotation, mouse-button-fix
#   5. Wires the lid script via acpid
#   6. Prints the MANUAL follow-up steps (GRUB, package install, WiFi
#      DKMS driver, Phosh autostart) — those are not touched automatically.
#
# Nothing in /etc/default/grub, /boot, or the kernel cmdline is modified.

set -euo pipefail

DRY=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  -h|--help)
    sed -n '2,20p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  "") : ;;
  *) echo "unknown flag: $1"; exit 2 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "run with sudo" >&2
  exit 1
fi

run() {
  if [ "$DRY" = 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== X836 setup =="
echo "repo:    $HERE"
echo "dry-run: $([ "$DRY" = 1 ] && echo yes || echo no)"
echo

# --- 1. Device detection ---------------------------------------------------
echo "[1/5] detecting device"
BOARD="$(dmidecode -s baseboard-product-name 2>/dev/null || echo unknown)"
CPU="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "  board: $BOARD"
echo "  cpu:   $CPU"
if [ "$BOARD" != "X836" ]; then
  echo "  WARNING: not an X836 board. Some fixes may not apply."
  echo "  (Ctrl-C to abort, any key to continue)"
  read -r -n1
fi
echo

# --- 2. Scripts to /usr/local/bin -----------------------------------------
echo "[2/5] installing scripts to /usr/local/bin"
for f in scripts/fix-audio.sh scripts/fix-rotation.sh scripts/mouse-button-fix.py scripts/lid.sh; do
  run "install -m 0755 '$HERE/$f' '/usr/local/bin/$(basename "$f")'"
done
echo

# --- 3. Configs under /etc ------------------------------------------------
echo "[3/5] installing configs"
run "install -D -m 0644 '$HERE/config/99-mouse-buttons.hwdb' /etc/udev/hwdb.d/99-mouse-buttons.hwdb"
run "install -D -m 0644 '$HERE/config/blacklist-iwlwifi.conf' /etc/modprobe.d/blacklist-iwlwifi.conf"
run "install -D -m 0644 '$HERE/config/lid-logind.conf' /etc/systemd/logind.conf.d/50-x836-lid.conf"
run "install -D -m 0644 '$HERE/config/nosleep.conf' /etc/systemd/sleep.conf.d/50-x836-nosleep.conf"
run "systemd-hwdb update"
run "udevadm trigger"
echo

# --- 4. Systemd services --------------------------------------------------
echo "[4/5] writing systemd services"

write_unit() {
  local path=$1
  local body=$2
  if [ "$DRY" = 1 ]; then
    printf '  [dry-run] write %s:\n' "$path"
    printf '%s\n' "$body" | sed 's/^/    | /'
  else
    printf '%s\n' "$body" > "$path"
    echo "  wrote $path"
  fi
}

write_unit /etc/systemd/system/x836-fix-audio.service "$(cat <<'UNIT'
[Unit]
Description=X836 — apply ES8336 ALSA mixer settings at boot
After=sound.target pipewire.service
Wants=sound.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-audio.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
)"

write_unit /etc/systemd/system/x836-mouse-button-fix.service "$(cat <<'UNIT'
[Unit]
Description=X836 — TrackPoint virtual mouse (scancode remap + damping)
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mouse-button-fix.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
)"

run "systemctl daemon-reload"
run "systemctl enable x836-fix-audio.service x836-mouse-button-fix.service"
echo

# --- 5. acpid lid handler -------------------------------------------------
echo "[5/5] wiring acpid lid handler"
run "install -D -m 0755 '$HERE/scripts/lid.sh' /etc/acpi/lid.sh"
write_unit /etc/acpi/events/lid "$(cat <<'EVT'
event=button/lid.*
action=/etc/acpi/lid.sh
EVT
)"
run "systemctl restart acpid || true"
echo

# --- Manual steps reminder ------------------------------------------------
cat <<'EOF'
Done. Manual follow-up (NOT applied by this script):

  (a) GRUB — edit /etc/default/grub:
      GRUB_TIMEOUT=0
      GRUB_TIMEOUT_STYLE=hidden
      GRUB_DISABLE_OS_PROBER=true
      GRUB_RECORDFAIL_TIMEOUT=0
      GRUB_CMDLINE_LINUX_DEFAULT="quiet fbcon=rotate:1 pcie_aspm=off"
      then: sudo update-grub && sudo chmod -x /etc/grub.d/30_os-prober

  (b) Phosh display rotation autostart:
      cp /usr/local/bin/fix-rotation.sh ~/.config/autostart/... (.desktop entry)
      (phoc.ini transform is ignored on this build — DBus autostart is the only way)

  (c) USB WiFi driver (if internal WiFi is broken):
      git clone https://github.com/morrownr/88x2bu-20210702.git
      cd 88x2bu-20210702 && sudo ./install-driver.sh

  (d) Backports kernel (required for SOF audio on GLK):
      sudo apt install -t bookworm-backports linux-image-amd64

  (e) Packages (see docs/device-profile.md for the full list)

Reboot after (a) and (d) to get the clean rotation + audio path.
EOF
