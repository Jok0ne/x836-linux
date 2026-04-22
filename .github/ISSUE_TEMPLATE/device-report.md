---
name: Device report
about: Report a unit you've tested this guide on — works, doesn't work, different hardware
title: "[device] <your brand sticker> — <J4105/J4125/J3455> — <works|partial|broken>"
labels: device-report
---

## My unit

<!-- Run these commands on the device and paste the output. All optional but more = better. -->

```
Brand sticker / seller:   
Board name:               <!-- sudo dmidecode -s baseboard-product-name -->
BIOS string:              <!-- sudo dmidecode -s bios-version -->
CPU:                      <!-- grep 'model name' /proc/cpuinfo | head -1 -->
RAM:                      <!-- free -h | awk '/Mem:/{print $2}' -->
Display resolution:       <!-- xrandr --query | grep ' connected' -->
Panel orientation:        <!-- portrait / landscape -->
Audio codec:              <!-- aplay -l -->
Touchscreen:              <!-- ls /sys/bus/i2c/devices/ -->
WiFi chip (internal):     <!-- lspci | grep -i network -->
WiFi chip (USB):          <!-- lsusb | grep -i wireless -->
Battery design capacity:  <!-- awk '/energy_full_design/{print $1/1e6" Wh"}' /sys/class/power_supply/BAT*/uevent -->
Kernel:                   <!-- uname -r -->
Distro:                   <!-- lsb_release -d -->
```

## Status

- [ ] Touchscreen
- [ ] Display rotation
- [ ] Audio (speaker)
- [ ] Audio (HDMI)
- [ ] TrackPoint + mouse buttons
- [ ] Webcam
- [ ] Bluetooth
- [ ] Lid switch
- [ ] Internal WiFi
- [ ] Keyboard
- [ ] Suspend/resume

## What works / what doesn't

<!-- Free-form. Mention what you had to do that's NOT in the guide, or what the guide missed on your unit. -->

## Revision hint

<!-- Which rev does this match from the 'Is this your device?' table?
- Rev A (J3455, 1024x600 landscape)
- Rev B (J4125, 1024x600 landscape)
- Rev C (J4105, 800x1280 portrait, X836)
- Something else / unclear -->
