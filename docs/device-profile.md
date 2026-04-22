# X836 — Device Profile & Post-Install Checklist

## Device identification

| | |
|---|---|
| **Type** | Generic 7" AliExpress pocket laptop |
| **Brand names** | Topton, TOPOSH, KAISERINC, Acogedor, Yoidesu, WOPOW, "A7" (all same HW) |
| **Board** | X836 (OEM, related to Chuwi LapBook family) |
| **BIOS** | AMI Aptio V, `X836_A_A25_M4U4P0E1C1S3P1A3R1F0W5T6_Intel3D_LM084` |
| **BIOS date** | 2023-05-25, board revision 2.1 |
| **Same device** | [paperstack.com/palmtop](https://paperstack.com/palmtop/) — confirmed identical |
| **HW DB** | [9 probes on linux-hardware.org](https://linux-hardware.org/?id=bios:american-megatrends-x836-a-a25-m4u4p0e1c1s3p1a3r1f0w5t6-intel3d-lm084-05-25-2023) |

### BIOS string decoding
- `X836` = board model
- `A25` = board revision
- `M4U4P0E1C1S3P1A3R1F0W5T6` = feature flags (unique, zero hits online)
- `Intel3D` = Gemini Lake platform
- `LM084` = LCD panel ID

## Hardware

| Component | Details |
|---|---|
| **CPU** | Intel Celeron J4105 @ 1.50 GHz (4 cores, Gemini Lake) |
| **RAM** | 8 / 12 GB LPDDR4 (varies by unit) |
| **SSD** | 128 GB – 1 TB (ShiJi, typical) |
| **GPU** | Intel UHD Graphics 600 |
| **Display** | 800×1280 native (portrait, DSI-1) — must be rotated |
| **Touchscreen** | Goodix Capacitive (I2C5, `GDIX1002`) — works |
| **TrackPoint** | `HTIX5288` (I2C8, Hantick) — works with fix |
| **Ethernet** | USB only (ASIX AX88179 known-good) |
| **Internal WiFi** | Intel 7265 (PCIe 02:00.0) — D3cold bug, broken on Linux |
| **External WiFi** | Realtek RTL8812BU (USB, `0bda:b812`) — works with `rtl88x2bu` |
| **Bluetooth** | Intel (USB) — works |
| **Camera** | Sunplus `SPCA2281` (USB port 6) — works |
| **Audio** | Everest ES8316/ES8336 (I2C, `ESSX8336`) + Intel SOF |
| **Battery** | 8.6 V, 22.2 Wh — charges slowly |
| **BIOS access** | AMI Aptio V 5.13, only Main/Security/Boot/Save visible (no Advanced tab) |

## Setup checklist (after fresh Debian install)

### OS + boot
- [ ] Debian 12 via `debootstrap` (no USB stick needed if you have SSH/existing OS)
- [ ] Kernel from `bookworm-backports` (6.12+)
- [ ] `/etc/default/grub`: `GRUB_TIMEOUT=0`, `GRUB_TIMEOUT_STYLE=hidden`, `GRUB_DISABLE_OS_PROBER=true`, `GRUB_RECORDFAIL_TIMEOUT=0`
- [ ] Kernel cmdline: `fbcon=rotate:1 pcie_aspm=off`
- [ ] Remove stale EFI boot entries (`efibootmgr -b NNNN -B`)
- [ ] `chmod -x /etc/grub.d/30_os-prober`

### Display
- [ ] `/etc/phosh/phoc.ini`: `[output:DSI-1]` with `scale = 1` (**`transform` is ignored!**)
- [ ] Autostart script `/usr/local/bin/fix-rotation.sh` — Mutter DBus (`transform=3`, `scale=1.25`)
- [ ] XDG autostart `.desktop` entry in `~/.config/autostart/`
- [ ] Console: `fbcon=rotate:1` kernel parameter
- [ ] `phoc.ini transform` does NOT work on this Phosh version — autostart script is the only way

### Lid close → screen off (solved)
- [x] Method: `busctl --user set-property org.gnome.Mutter.DisplayConfig /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i 3` (off) / `i 0` (on)
- [x] `acpid`: `/etc/acpi/events/lid` + `/etc/acpi/lid.sh`
- [x] `logind`: `HandleLidSwitch=ignore` (we handle it ourselves)
- Do NOT use `wlr-randr --off` (kills the session!)
- Do NOT use `HandleLidSwitch=lock` (shows lockscreen)
- Do NOT use `echo 0 > brightness` (only dims, screen still glows)
- When editing `lid.sh` over SSH: do NOT use `<<HEREDOC` (variables get expanded!) — use `<<'HEREDOC'` (single-quoted)

### Network
- [ ] NetworkManager (**not** `networking.service`)
- [ ] WiFi driver: `rtl88x2bu` via DKMS (`git clone https://github.com/morrownr/88x2bu-20210702.git`)
- [ ] `nmcli device wifi connect "<YOUR_SSID>" password "<YOUR_PASSWORD>"`
- [ ] Blacklist broken internal WiFi: `/etc/modprobe.d/blacklist-iwlwifi.conf` (iwlwifi + iwlmvm)
- [ ] (optional) Tailscale with auto-join via pre-auth key

### Services to disable (boot speed)
- [ ] Mask `networking.service` (saves ~60 s!)
- [ ] Mask `ifupdown-pre.service`
- [ ] Mask `plymouth-quit-wait` / `quit` / `start`
- [ ] Mask `NetworkManager-wait-online`

### Disable sleep
- [ ] `systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`
- [ ] `/etc/systemd/sleep.conf.d/nosleep.conf`
- [ ] logind: `HandleLidSwitch=ignore`

### User + SSH
- [ ] Create your user, add to `sudo` group
- [ ] Add your SSH public key to `~/.ssh/authorized_keys`
- [ ] (optional) Auto-login on tty1: `/etc/systemd/system/getty@tty1.service.d/autologin.conf`

### TrackPoint mouse buttons
- [ ] hwdb remap: `/etc/udev/hwdb.d/99-mouse-buttons.hwdb` (`0x4C` → `btn_left`, `0xDD` → `btn_right`)
- [ ] Virtual mouse: `/usr/local/bin/mouse-button-fix.py` (needs `python3-evdev`)
- [ ] Systemd service: `mouse-button-fix.service`
- [ ] Tuning: `MAX_SPEED=5`, `DAMPING=0.6`
- [ ] The TrackPoint itself is also grabbed by the fix script and forwarded

### Phosh UI
- [ ] `gsettings set sm.puri.phoc auto-maximize true`, `scale-to-fit true`
- [ ] Disable screen blanking
- [ ] Disable lockscreen (personal preference)
- [ ] CPU governor: `performance`
- [ ] Swappiness: `10`

### Packages
```text
# Base
linux-image-amd64 firmware-iwlwifi firmware-misc-nonfree firmware-sof-signed
grub-efi-amd64 openssh-server sudo curl net-tools iproute2
wpasupplicant network-manager i2c-tools libgpiod2 gpiod
locales console-setup btrfs-progs usbutils bc pciutils
dkms build-essential linux-headers-$(uname -r) git

# Desktop
phosh phoc squeekboard gnome-console nautilus gdm3
gnome-settings-daemon gnome-shell pipewire pipewire-pulse pipewire-alsa wireplumber
alsa-ucm-conf alsa-utils

# Apps
kitty firefox-esr grim wlr-randr evtest libinput-tools acpica-tools flashrom

# CLI tools
zsh fzf bat htop tmux ripgrep fd-find ncdu ranger neofetch
# + starship (via installer), zoxide (via installer)
```

## Audio (solved)

### Hardware
- Codec: Everest ES8316/ES8336 on I2C (ACPI HID: `ESSX8336`)
- Platform: `sof-audio-pci-intel-apl` (Intel SOF)
- NHLT: I²S(4) `ssp_mask=0x5` (SSP0+SSP2), `MCLK mask=0x2` (MCLK1)
- Topology: `sof-glk-es8336-ssp2.tplg` (auto-detected)

### Status
- Sound card detected (`sof-essx8336`)
- Playback devices visible via `aplay -l`
- Speaker clicks on mute/unmute (physical speaker confirmed)
- No audio output despite mixer at max (out-of-the-box)
- HDMI IPC error: `ipc tx error for 0x60010000 ... -5` (HDMI pipeline mismatch — ignore)

### Quirks tested
| Quirk | Result |
|---|---|
| `quirk=0x0` (SSP0) | Topology SSP2 loaded, card present but no sound |
| `quirk=0x2` (SSP2) | IPC error, no card |
| `quirk=0x10` (SSP0+GPIO1) | SSP2.OUT widget error, card failed |
| No quirk (auto) | SSP2 via NHLT, IPC error on HDMI |
| SSP2 topology overridden with SSP0 | Card present, no sound |

### References
- [paperstack.com/palmtop](https://paperstack.com/palmtop/) — audio works out-of-the-box on Ubuntu 24.04
- [gnickm/sof-essx8336-debian-fix](https://github.com/gnickm/sof-essx8336-debian-fix) — Debian fix package
- [thesofproject/linux#3336](https://github.com/thesofproject/linux/issues/3336) — GLK+ES8336 fix
- [thesofproject/linux#2955](https://github.com/thesofproject/linux/issues/2955) — ESSX8336 Debian
- [ES8336 SOF Wiki](https://github.com/thesofproject/linux/wiki/ES8336-support)
- [`sof_es8336.c`](https://github.com/torvalds/linux/blob/master/sound/soc/intel/boards/sof_es8336.c)

### Solution
- **No quirk override** — auto-detect (SSP2 via NHLT) is correct
- SOF firmware `v2025.12.2` (from GitHub, not the Debian package)
- ALSA mixer via `amixer cset` (NOT `sset`!) at every boot
- PipeWire as audio server
- Systemd service `fix-audio.service` → `/usr/local/bin/fix-audio.sh`
- HDMI IPC error: ignore (HDMI audio does not work, speaker does)

### Mixer values (`fix-audio.sh`)
```bash
amixer -c 0 cset name='Speaker Switch' on
amixer -c 0 cset name='Headphone Switch' on
amixer -c 0 cset name='Headphone Playback Volume' 3,3
amixer -c 0 cset name='Right Headphone Mixer Right DAC Switch' on
amixer -c 0 cset name='Left Headphone Mixer Left DAC Switch' on
amixer -c 0 cset name='DAC Playback Volume' 192,192
amixer -c 0 cset name='Headphone Mixer Volume' 11,11
```

## Known issues

### Intel 7265 WiFi broken on Linux
- Works under Windows on this same hardware — **not** a hardware fault
- Linux/ACPI bug: `D3cold` → `D0` power state transition fails
- All OS-level fixes failed (see WiFi fix attempts below)
- BIOS-level fix required (`setup_var.efi` or a proper BIOS mod)
- `iwlwifi` blacklisted for faster boot

### Display rotation not persistent
- `phoc.ini transform` is ignored by this Phosh build
- `monitors.xml` not written/read by Phosh
- Only solution: autostart script via Mutter DBus API
- GUI settings changes do NOT survive a reboot

### HTIX5288 TrackPoint
- Known Chuwi LapBook–family issue
- Mouse buttons wired as keyboard events (scancodes)
- Runtime PM can cause freezes
- Kernel patch exists: `patchwork.kernel.org/patch/10597519/`

### Battery
- 22.2 Wh — charges slowly (barrel plug, 12V/2A)
- Capacity reporting is unreliable
- Best run on AC adapter

## Hardware deep-dive (ACPI/DSDT analysis)

The X836 board is derived from an Intel tablet/convertible reference design. Many ACPI-defined devices are **not physically populated**.

### Physically present & active
| Device | Type | Bus | Notes |
|---|---|---|---|
| Goodix `GDIX1002` | Touchscreen | I2C5 | works |
| `HTIX5288` | TrackPoint | I2C8 | works (Hantick) |
| Intel 7265 | WiFi | PCIe 02:00.0 | D3cold bug |
| Intel BT | Bluetooth | USB | works |
| Sunplus `SPCA2281` | Webcam | USB port 6 | works |
| ES8316/8336 | Audio codec | I2C + I²S | works (with fix) |
| SEN4 (`INT3403`) | Skin thermistor | EC (TSR4) | `thermal_zone1`, active |
| Lid switch | Lid sensor | ACPI | works |
| Intel HID | 5-button array | Platform | works |
| PC speaker | Beeper | ISA | present |

### Defined in ACPI but NOT populated
| Device | Chip | Bus | Checked via |
|---|---|---|---|
| `GPS1` | BCM4752 | UART2 | ACPI `_STA = 0` |
| `NFC1` | NXP NPC100 | I2C1 @ `0x29` | no I²C response |
| `FPNT` | FS4304 fingerprint | SPI1 | ACPI `_STA = 0` |
| `MODM` | Modem | PCIe RP05 | no PCIe device |
| `UBTC` | USB Type-C | EC | ACPI `_STA = 0` |
| `SEN1` | CPU VR thermistor | EC (TSR1) | BIOS disabled |
| `SEN2` | DIMM thermistor | EC (TSR2) | BIOS disabled |
| `SEN3` | Ambient thermistor | EC (TSR3) | BIOS disabled |
| `ALPS0001` TPD0 | Touchpad | I2C4 | ACPI `_STA = 0` |

### Bus overview
- 4× GPIO chips, 215 lines (`INT3453`)
- 8× I²C DesignWare + 1× SMBus + 4× GPU DDC = 13 buses
- 3× SPI (`pxa2xx-spi`)
- 4× UART
- Backlight: `intel_backlight`, max = 640

### BIOS dump & RE
- BIOS dump extracted via `flashrom` (8 MB SPI chip)
- ACPI dumps on-device: `/tmp/dsdt.dsl`, `/tmp/SSDT1-10.dsl`
- BIOS exposes only 4 tabs (Main / Security / Boot / Save & Exit)
- Hidden menus: `Ctrl+F1`, `Alt+F1`, `Shift+F1` all do NOT work
- Next steps: `UEFITool` → IFR extract → `setup_var.efi`

### WiFi fix attempts (all failed)
| Attempt | Result |
|---|---|
| `pcie_aspm=off` | no effect |
| `acpi_osi=Windows` | no effect |
| Kernel 6.1 → 6.12.74 | no effect |
| PCI runtime power=on | no effect |
| PCI remove + rescan | no effect |
| `setpci L1SubCtl1=0` | no effect |
| `setpci LnkCtl ASPM=off` | no effect |
| suspend/wake | machine powered off |
| Root port `00:13.2`: L1 + L1.2 substates active | — |
| Problem occurs BEFORE Linux boot | — |
