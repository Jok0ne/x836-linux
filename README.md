<p align="center">
  <img src="docs/header.jpg" alt="x836-linux" width="100%">
</p>

<h3 align="center">Complete Linux setup guide for the X836 7-inch pocket laptop<br><sub>(AliExpress / Topton / TOPOSH / KAISERINC / Acogedor / Yoidesu / WOPOW / "A7" — same hardware, dozens of stickers)</sub></h3>

<p align="center">
  <img src="https://img.shields.io/badge/os-debian%2012-06b6d4?style=for-the-badge&labelColor=0c1929" alt="Debian 12">
  <img src="https://img.shields.io/badge/desktop-phosh-67e8f9?style=for-the-badge&labelColor=0c1929" alt="Phosh">
  <img src="https://img.shields.io/badge/kernel-6.12-06b6d4?style=for-the-badge&labelColor=0c1929" alt="Kernel">
  <img src="https://img.shields.io/badge/boot-27s-67e8f9?style=for-the-badge&labelColor=0c1929" alt="Boot 27s">
  <img src="https://img.shields.io/badge/license-MIT-06b6d4?style=for-the-badge&labelColor=0c1929" alt="MIT">
</p>

<p align="center">
  <a href="#tldr">TL;DR</a> ·
  <a href="#the-story">Story</a> ·
  <a href="#the-device">Device</a> ·
  <a href="#is-this-your-device">Is this yours?</a> ·
  <a href="#quickstart">Quickstart</a> ·
  <a href="#what-works--what-doesnt">Status</a> ·
  <a href="#the-fixes">Fixes</a> ·
  <a href="#why-this-device-is-weird">Why it's weird</a> ·
  <a href="#troubleshooting">Troubleshooting</a> ·
  <a href="#references">Refs</a>
</p>

---

## TL;DR

This repo turns the **X836 7-inch pocket laptop** (aka Topton L4 / GTZS / WOPOW / KAISERINC … same HW, dozens of stickers) into a **usable Linux device** — stable, 27-second boot, working touch, audio, rotation, and TrackPoint.

**Working:**
- Touchscreen · Display rotation · Audio (speaker) · TrackPoint (with fix) · Webcam · Bluetooth · Lid switch · USB WiFi · Keyboard

**Broken (hardware/BIOS, not fixable from userspace):**
- Internal Intel 7265 WiFi (D3cold PCI bug) · HDMI audio

> ⚠️ **If your unit has Intel 7265, internal WiFi will NOT work under Linux.** This is a hardware/firmware-level issue (PCIe D3cold wake), not a driver bug — no kernel parameter or module option fixes it. Plan for a USB WiFi adapter (`RTL8812BU` tested). Some units ship with Realtek RTL8821CE instead — that one has the same issue on this board.

**Installation:**

```bash
sudo apt install -t bookworm-backports linux-image-amd64   # SOF audio needs a newer kernel
git clone https://github.com/Jok0ne/x836-linux.git && cd x836-linux
sudo ./setup.sh --dry-run   # see what will change
sudo ./setup.sh             # apply everything
```

**After reboot: a Debian 12 + Phosh touch tablet you'd actually want to use.**

---

## The story

This laptop has no real name. It's sold as **Topton**, **TOPOSH**, **KAISERINC**, **Acogedor**, **Yoidesu**, **A7**, **WOPOW** — and a dozen more. Different stickers, same hardware. The BIOS says "Default string" for vendor, product, and manufacturer. Nobody knows who actually makes it.

By dumping the ACPI tables and analyzing the BIOS, we discovered this is actually an **Intel tablet/convertible reference design** (board code `X836`) related to the **Chuwi LapBook** family. The board was originally designed for a full-featured tablet with GPS (Broadcom BCM4752), NFC (NXP NPC100), fingerprint reader (FS4304), LTE modem, and USB-C — but the Chinese manufacturers cheaped out and only populated the basics: screen, keyboard, touchpad, WiFi, webcam.

The ACPI tables still define all these ghost devices. When you scan the I2C buses or read the DSDT, you find the digital ghosts of a device that could have been much more.

Some units ship with **Intel 7265 WiFi** (broken under Linux due to a PCI D3cold power state bug), others with **Realtek RTL8821CE** (works). There's no way to tell which you'll get until you open it. The BIOS has hidden Advanced settings locked behind AMI Aptio V — no keyboard shortcut unlocks them, but we dumped the BIOS chip and it's ready for RE.

Despite all this, with the right fixes, it makes a surprisingly good little Linux touch tablet. This guide documents everything we learned getting it there — every fix, every failure, every dead end.

> **Reference:** Dave Minter documented the [same device on paperstack.com](https://paperstack.com/palmtop/) running Ubuntu 24.04.

## The device

<p align="center">
  <img src="docs/device.jpg" alt="X836 pocket laptop running Kali Linux outdoors" width="100%">
  <br>
  <sub><i>The actual unit — Kali boot in the garden. USB WiFi adapter on the right.</i></sub>
</p>

| | |
|---|---|
| **Board** | X836 (OEM, Intel reference design, Chuwi LapBook family) |
| **CPU** | Intel Celeron J4105 @ 1.50 GHz (Gemini Lake) |
| **RAM** | 8/12 GB LPDDR4 |
| **Storage** | 128GB – 1TB SSD (ShiJi) |
| **Display** | 7" 800×1280 IPS Touch (Portrait, DSI-1) |
| **Touch** | Goodix Capacitive (I2C, GDIX1002) |
| **TrackPoint** | HTIX5288 (Hantick, I2C) |
| **Audio** | Everest ES8316/ES8336 (I2C + Intel SOF) |
| **WiFi** | Intel 7265 **or** Realtek RTL8821CE (varies!) |
| **Bluetooth** | Intel (USB) |
| **Webcam** | Sunplus SPCA2281 |
| **Battery** | 22.2 Wh |
| **Weight** | ~620 g |
| **BIOS** | AMI Aptio V (`X836_A_A25_...Intel3D_LM084`) |

### Is this your device?

The same 7-inch clamshell body has been sold under **dozens of brand names** (Topton, TOPOSH, KAISERINC, GTZS, WOPOW, Acogedor, Yoidesu, A7 …) across **at least three hardware revisions** since 2021. They share quirks (ES8336 audio, Goodix GDIX1002 touchscreen, 22.2 Wh battery, keyboard-scancode mouse buttons) but differ on CPU, display, and WiFi. **This guide targets the X836 / J4105 portrait-panel revision.**

| Feature | Rev A — **GTZS X133** (Jun 2021)¹ | Rev B — **L4 J4125** (Sep 2022)² | Rev C — **X836** (this guide) |
|---|---|---|---|
| CPU | Celeron J3455 (Apollo Lake) | Celeron J4125 (Gemini Lake R) | Celeron **J4105** (Gemini Lake) |
| RAM | 8 GB | 8 GB | 8 / 12 GB LPDDR4 |
| Display | 1024×600 **landscape** LVDS | 1024×600 **landscape** | 800×1280 **portrait** DSI-1 |
| Battery | 22.2 Wh | 3000 mAh (~22 Wh) | 22.2 Wh |
| Audio codec | ES8336 | ES8336 | ES8316 / ES8336 |
| Touchscreen | Goodix GDIX1002 | Goodix | Goodix GDIX1002 |
| WiFi | Realtek RTL8821CU | WiFi 5 | Intel 7265 **or** RTL8821CE |
| HDMI | mini-HDMI | mini-HDMI | **none** |
| Pen | 2048 pressure | 2048 pressure | no |
| Launch price | ~$300 | ~$300 | OEM, varies |

¹ vitor.io — [*"Notes on the GTZS Pocket Book 7-X133 WOPOW 7-inch mini laptop"*](http://vitor.io/notes-7-inch-mini-laptop) (2021-12)
² liliputing.com — [*"This 7 inch mini-laptop with a Celeron J4125 processor sells about for $300 and up"*](https://liliputing.com/this-7-inch-mini-laptop-with-a-celeron-j4125-processor-sells-about-for-300-and-up/) (2022-09)

**30-second Linux check — is yours Rev C?**

```bash
sudo dmidecode -s baseboard-product-name   # expect: X836
grep "model name" /proc/cpuinfo | head -1  # expect: Celeron J4105
ls /sys/class/drm/ | grep DSI              # expect: card*-DSI-1 (portrait panel)
awk '/energy_full_design/{print $1/1e6" Wh"}' /sys/class/power_supply/BAT*/uevent 2>/dev/null
                                            # expect: ~22.2 Wh
```

If CPU/board differ → Rev A or B → see vitor.io for J3455 or the Liliputing J4125 writeup. Fixes in this guide still mostly apply (audio/touch/pointer quirks are shared), but display rotation and WiFi parts won't.

## Quickstart

**Prerequisites:**
- Debian 12 (bookworm) installed on the device — via USB stick or `debootstrap` from an existing Linux
- Network (USB Ethernet or USB WiFi — internal Intel 7265 does NOT work, see [Is this your device?](#is-this-your-device))
- Kernel 6.12+ from `bookworm-backports` (the SOF ES8336 audio path is not in the stock 6.1 kernel)

**Install:**

```bash
# 1. Backports kernel (needed for audio)
sudo apt install -t bookworm-backports linux-image-amd64
sudo reboot

# 2. Clone and inspect
git clone https://github.com/Jok0ne/x836-linux.git
cd x836-linux
sudo ./setup.sh --dry-run   # prints every action, changes nothing

# 3. Apply
sudo ./setup.sh
```

**What `setup.sh` does** (all idempotent, safe to re-run):

1. Detects the board (warns if you're not on an X836)
2. Copies `fix-audio.sh`, `fix-rotation.sh`, `mouse-button-fix.py`, `lid.sh` → `/usr/local/bin/`
3. Installs configs: udev hwdb for mouse-button scancodes, `iwlwifi` blacklist, logind lid-policy, systemd-sleep disable
4. Creates + enables two systemd services: `x836-fix-audio`, `x836-mouse-button-fix`
5. Wires the lid script via `acpid`
6. Prints the **manual** follow-up steps (GRUB edits, Phosh autostart, USB WiFi DKMS, packages) — it won't touch GRUB or `/etc/default/*` for you.

**After reboot you get:**

```
boot time:  ~27 s (vs. ~2 min stock)
audio:      speaker works, HDMI does not
rotation:   portrait panel displayed landscape (via Mutter DBus)
trackpoint: left/right click work, speed-capped + damped
lid close:  screen off + CPU powersave + BT off (reversed on open)
wifi:       use USB RTL8812BU; internal Intel 7265 stays blacklisted
```

**If something breaks →** see [Troubleshooting](#troubleshooting), or open an issue.

## What works / what doesn't

<table>
<tr><th>Feature</th><th>Status</th><th>Notes</th></tr>
<tr><td>Touchscreen</td><td>✅</td><td>Works out of the box</td></tr>
<tr><td>Display Rotation</td><td>✅</td><td>Autostart script needed (see Fixes)</td></tr>
<tr><td>Audio (Speaker)</td><td>✅</td><td>Needs mixer fix at boot (systemd service)</td></tr>
<tr><td>TrackPoint</td><td>✅</td><td>Needs button remap + virtual mouse</td></tr>
<tr><td>Webcam</td><td>✅</td><td>Works out of the box</td></tr>
<tr><td>Bluetooth</td><td>✅</td><td>Works out of the box</td></tr>
<tr><td>Lid Switch</td><td>✅</td><td>Screen off/on via <code>busctl</code></td></tr>
<tr><td>USB WiFi</td><td>✅</td><td>RTL8812BU via <code>rtl88x2bu</code> driver</td></tr>
<tr><td>Keyboard</td><td>✅</td><td>Works out of the box</td></tr>
<tr><td>Internal WiFi (Intel 7265)</td><td>❌</td><td>D3cold PCI bug. BIOS-level fix needed. Swap to AX210 may fix.</td></tr>
<tr><td>Internal WiFi (RTL8821CE)</td><td>⚠️</td><td>Some units have this instead — works under Ubuntu 24.04</td></tr>
<tr><td>HDMI Audio</td><td>❌</td><td>IPC pipeline mismatch</td></tr>
<tr><td>Rotation via <code>phoc.ini</code></td><td>❌</td><td><code>transform</code> ignored, autostart script needed</td></tr>
</table>

## The fixes

### Display rotation

The display is a portrait panel (800×1280) mounted landscape. Phosh doesn't persist rotation settings, so we use an autostart script:

```bash
# /usr/local/bin/fix-rotation.sh
python3 -c "
import dbus
bus = dbus.SessionBus()
proxy = bus.get_object('org.gnome.Mutter.DisplayConfig', '/org/gnome/Mutter/DisplayConfig')
iface = dbus.Interface(proxy, 'org.gnome.Mutter.DisplayConfig')
serial, monitors, logical, props = iface.GetCurrentState()
mode_id = str(monitors[0][1][0][0])
monitors_config = dbus.Array([
    dbus.Struct([
        dbus.Int32(0), dbus.Int32(0), dbus.Double(1.25),
        dbus.UInt32(3), dbus.Boolean(True),
        dbus.Array([
            dbus.Struct([
                dbus.String('DSI-1'), dbus.String(mode_id),
                dbus.Dictionary({}, signature='sv'),
            ], signature='ssa{sv}')
        ], signature='a(ssa{sv})')
    ], signature='(iiduba(ssa{sv}))')
], signature='a(iiduba(ssa{sv}))')
iface.ApplyMonitorsConfig(serial, dbus.UInt32(2), monitors_config, dbus.Dictionary({}, signature='sv'))
"
```

> **Note:** `phoc.ini` `transform` setting is ignored by this Phosh version. The DBus API is the only way.

### Audio

The ES8336 codec works with Intel SOF but needs correct ALSA mixer settings at boot:

```bash
# /usr/local/bin/fix-audio.sh
amixer -c 0 cset name='Speaker Switch' on
amixer -c 0 cset name='Headphone Switch' on
amixer -c 0 cset name='Headphone Playback Volume' 3,3
amixer -c 0 cset name='Right Headphone Mixer Right DAC Switch' on
amixer -c 0 cset name='Left Headphone Mixer Left DAC Switch' on
amixer -c 0 cset name='DAC Playback Volume' 192,192
amixer -c 0 cset name='Headphone Mixer Volume' 11,11
```

> **Important:** Use `amixer cset` not `amixer sset` — PipeWire grabs the device and `sset` can't find controls.

### TrackPoint mouse buttons

The mouse buttons send keyboard scancodes instead of mouse events:

- Left button: `KEY_KP5` (scancode `0x4C`)
- Right button: `KEY_COMPOSE` (scancode `0xDD`)

Fix requires two steps:

1. **udev hwdb** remaps scancodes to `BTN_LEFT`/`BTN_RIGHT`
2. **Virtual mouse** (`python3-evdev`) forwards button events from keyboard device to a virtual mouse device — Wayland ignores `BTN` events from keyboard devices

See [`scripts/mouse-button-fix.py`](scripts/mouse-button-fix.py) for the full solution including TrackPoint speed capping (`MAX_SPEED=5`, `DAMPING=0.6`).

### Lid switch

Screen off/on via Mutter DBus API (the only method that works without killing the Phosh session):

```bash
# Screen OFF
busctl --user set-property org.gnome.Mutter.DisplayConfig \
  /org/gnome/Mutter/DisplayConfig \
  org.gnome.Mutter.DisplayConfig PowerSaveMode i 3

# Screen ON
busctl --user set-property org.gnome.Mutter.DisplayConfig \
  /org/gnome/Mutter/DisplayConfig \
  org.gnome.Mutter.DisplayConfig PowerSaveMode i 0
```

Wired up via `acpid` — see [`scripts/lid.sh`](scripts/lid.sh). When lid is closed, the script also:

- Switches CPU governor to `powersave` (800 MHz)
- Disables Bluetooth

When lid is opened, everything is restored to `performance` mode.

> ⚠️ Do NOT use `wlr-randr --off` — it removes the output from the compositor and kills the session.
> ⚠️ Do NOT use `HandleLidSwitch=lock` — it shows a lock screen and may cause black screen after unlock.
> ⚠️ Do NOT use `echo 0 > brightness` — only dims, screen still glows.

### Boot speed

Default Debian 12 boot: **~2 minutes**. After optimization: **~27 seconds**.

| Optimization | Time saved |
|---|---|
| Mask `networking.service` | 60 s |
| Mask `plymouth-quit-wait` | 20 s |
| Mask `NetworkManager-wait-online` | variable |
| Blacklist `iwlwifi` | 10 s |
| `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden` | 2 s |
| `GRUB_DISABLE_OS_PROBER=true` | prevents 30 s os-prober menu |
| `GRUB_RECORDFAIL_TIMEOUT=0` | prevents 30 s recordfail wait |
| `chmod -x /etc/grub.d/30_os-prober` | belt and suspenders |

## Why this device is weird

This isn't an ordinary cheap laptop. It's the **digital ghost of a much more ambitious device** that Chinese assemblers stripped down and sold under a dozen brand stickers. If you open up its firmware, you find fingerprints of something that was supposed to be a full-featured convertible tablet.

### The Intel reference-design origin

The BIOS string `X836_A_A25_M4U4P0E1C1S3P1A3R1F0W5T6_Intel3D_LM084` decodes to an **Intel tablet/convertible reference platform**, related to the Chuwi LapBook family. `X836` is the board, `Intel3D` is the Gemini Lake platform, and that opaque `M4U4P0...` string is a feature-flag map — with **zero hits anywhere on the internet**. Whoever assembles this doesn't show up in search.

### The ACPI ghost devices

The ACPI tables still describe the full reference design. The hardware they describe is mostly **not there** — the assemblers cheaped out and populated only the essentials.

| Defined in ACPI | Chip | Actually present? | Evidence |
|---|---|---|---|
| GPS | Broadcom BCM4752 | ✗ | ACPI `_STA = 0` |
| NFC | NXP NPC100 | ✗ | no I²C response at `0x29` |
| Fingerprint | FS4304 | ✗ | ACPI `_STA = 0` |
| LTE modem | unknown | ✗ | no PCIe device at RP05 |
| USB Type-C | USBC000 | ✗ | ACPI `_STA = 0` |
| Secondary touchpad | ALPS0001 TPD0 | ✗ | ACPI `_STA = 0` |
| Thermistors SEN1–3 | INT3403 | ✗ | BIOS-disabled |
| Skin thermistor SEN4 | INT3403 | ✓ | `thermal_zone1` is live |

Scan the I²C buses and you find the **digital ghosts** of a device that could have been.

### The silicon overkill

For a plastic 7-inch laptop with 4 keys of quirks, the SoC exposes:

- **215 GPIO lines** across 4 gpio-chips (`INT3453`)
- **13 I²C buses** (8× DesignWare, 1× SMBus, 4× GPU DDC)
- **3 SPI buses**, **4 UARTs**
- All of which go mostly unused

### The locked BIOS

AMI Aptio V, only 4 tabs visible (Main / Security / Boot / Save & Exit). The **Advanced** tab is there in the firmware — we dumped the chip via `flashrom` — but every keyboard shortcut that normally reveals it (`Ctrl+F1`, `Alt+F1`, `Shift+F1`) is disabled. Fix path: `UEFITool` → IFR extract → `setup_var.efi`. That's probably also where the D3cold WiFi bug gets fixed.

### Why it matters

This board gets sold under **Topton · TOPOSH · KAISERINC · GTZS · WOPOW · Acogedor · Yoidesu · "A7"** and more. The BIOS reports "Default string" for vendor/product/manufacturer. **Nobody knows who actually makes it.** That's unusual — most hardware is at least identified by its OEM. This one is a rebadge chain with no known origin.

If you're holding one of these, you're holding a small mystery. This guide's job is to let you use it anyway.

## Troubleshooting

<details>
<summary><b>Internal WiFi (Intel 7265) fails to probe</b></summary>

<br>

Does NOT work under Linux on this board. The card cannot wake from D3cold power state:

```
iwlwifi 0000:02:00.0: HW_REV=0xFFFFFFFF, PCI issues?
iwlwifi: probe failed with error -5
```

**Tested and failed:** `pcie_aspm=off`, `acpi_osi=Windows`, kernel 6.1/6.12, PCI remove+rescan, `setpci` ASPM disable, suspend/wake trick.

**Root cause:** BIOS/ACPI does not properly initialize the PCIe slot. Fix requires BIOS-level modification via [`setup_var.efi`](https://github.com/datasone/setup_var.efi) (hidden BIOS settings).

**Workaround:** USB WiFi adapter (RTL8812BU recommended).

> Some units ship with Realtek RTL8821CE instead of Intel 7265. The Realtek card has the same D3cold issue on this board.

</details>

<details>
<summary><b>Audio silent after login</b></summary>

<br>

Mixer gets reset on session start. Ensure the systemd service calling `fix-audio.sh` runs **after** PipeWire is ready and uses `amixer cset` (not `sset`). See [The Fixes → Audio](#audio).

</details>

<details>
<summary><b>Screen upside-down after boot</b></summary>

<br>

`phoc.ini` `transform` is ignored on this Phosh build. Use the DBus autostart script in [The Fixes → Display rotation](#display-rotation).

</details>

## Detailed guides

- [`docs/device-profile.md`](docs/device-profile.md) — full hardware profile
- _installation / display / audio / trackpoint / wifi / lid-switch / boot-speed_ — WIP (structured write-up coming)

## Related

**Same product family, different revisions:**
- [vitor.io — GTZS Pocket Book 7-X133 WOPOW](http://vitor.io/notes-7-inch-mini-laptop) — Rev A (J3455) Ubuntu 21.10 → 24.10 notes, same ES8336/Goodix/battery
- [paperstack.com/palmtop](https://paperstack.com/palmtop/) — Dave Minter's Ubuntu 24.04 writeup (X836, same as this guide)
- [liliputing.com — Topton L4 (Jun 2021)](https://liliputing.com/topton-l4-is-mini-laptop-with-a-7-inch-display-8gb-of-ram-and-299-starting-price/) — Rev A launch article
- [liliputing.com — J4125 variant (Sep 2022)](https://liliputing.com/this-7-inch-mini-laptop-with-a-celeron-j4125-processor-sells-about-for-300-and-up/) — Rev B
- [linux-hardware.org probes](https://linux-hardware.org/?id=bios:american-megatrends-x836-a-a25-m4u4p0e1c1s3p1a3r1f0w5t6-intel3d-lm084-05-25-2023) — 9 X836 probes

**Upstream fixes & tools:**
- [gnickm/sof-essx8336-debian-fix](https://github.com/gnickm/sof-essx8336-debian-fix) — audio fix reference
- [thesofproject/linux#3336](https://github.com/thesofproject/linux/issues/3336) — ES8336 GLK audio thread
- [ES8336 SOF Wiki](https://github.com/thesofproject/linux/wiki/ES8336-support)
- [`setup_var.efi`](https://github.com/datasone/setup_var.efi) — BIOS variable editor

## Future work

Things worth chasing — open issue / PR if you've cracked any of these:

- **BIOS unlock** — extract the hidden Advanced tab via `UEFITool` IFR + `setup_var.efi`. The BIOS dump is available on request.
- **D3cold WiFi fix** — determine which BIOS variable disables the broken PCIe power state, flip it, document the procedure.
- **ACPI patching** — clean DSDT overrides to hide the ghost devices (GPS, NFC, fingerprint, LTE) so drivers stop probing them.
- **HDMI audio** — the IPC pipeline mismatch on SOF. Upstream SOF thread is stale.
- **Full `debootstrap` installer script** — currently documented, not scripted. A `install-debian.sh` that runs from any live Linux would close the loop.
- **Photo gallery** — more real-world units with different brand stickers to help readers identify their hardware.

## Contributing

Got a different WiFi chip? A BIOS dump from a rev we haven't seen? A fix for Intel 7265? Please open an issue with this info:

```
- Brand sticker / seller:    (Topton / GTZS / WOPOW / KAISERINC / …)
- Board name:                (sudo dmidecode -s baseboard-product-name)
- CPU:                       (grep 'model name' /proc/cpuinfo | head -1)
- Display resolution:        (xrandr --query | grep ' connected')
- Audio codec:               (aplay -l)
- WiFi chip:                 (lspci | grep -i network   OR   lsusb)
- Kernel:                    (uname -r)
- Distro:                    (lsb_release -d)
- What works:
- What doesn't:
```

PRs welcome — please keep the style and scope of the existing sections. Fixes that add platform-specific secrets/paths will be asked to use placeholders before merge.

## License

MIT — see [`LICENSE`](LICENSE).

---

<sub>Header + badge palette: `#06b6d4` cyan / `#67e8f9` light cyan / `#0c1929` navy label.</sub>
