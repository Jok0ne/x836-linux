#!/bin/bash
# Called by acpid on lid open/close. Install as /etc/acpi/lid.sh.
#
# Resolves the session user automatically. Override with DESK_USER env
# from the acpid event file if needed.

DESK_USER="${DESK_USER:-$(loginctl list-users --no-legend | awk '$2!="root"{print $2; exit}')}"
DESK_UID="$(id -u "$DESK_USER" 2>/dev/null)"
: "${DESK_USER:?set DESK_USER env var or ensure a login session exists}"
: "${DESK_UID:?could not resolve UID for $DESK_USER}"

# Bluetooth USB path is unit-specific. Check with `lsusb -t` if yours differs.
BT_USB_PATH="${BT_USB_PATH:-/sys/bus/usb/devices/1-4/bConfigurationValue}"

set_powersave() {
    sudo -u "$DESK_USER" \
        XDG_RUNTIME_DIR="/run/user/$DESK_UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$DESK_UID/bus" \
        busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig \
        org.gnome.Mutter.DisplayConfig PowerSaveMode i "$1"
}

set_governor() {
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$1" > "$cpu"
    done
}

LID_STATE=$(awk '{print $2}' /proc/acpi/button/lid/LID0/state)

if [ "$LID_STATE" = "closed" ]; then
    set_powersave 3
    set_governor powersave
    echo 0 > "$BT_USB_PATH" 2>/dev/null
else
    set_powersave 0
    set_governor performance
    echo 1 > "$BT_USB_PATH" 2>/dev/null
fi
