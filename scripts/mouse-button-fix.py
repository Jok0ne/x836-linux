#!/usr/bin/env python3
"""Virtual mouse device for X836 TrackPoint button remapping.

The X836 laptop's mouse buttons send keyboard scancodes (KEY_KP5, KEY_COMPOSE)
instead of mouse events. This script creates a virtual mouse that:
1. Forwards BTN_LEFT/BTN_RIGHT from the keyboard device
2. Grabs and forwards the TrackPoint with speed capping + damping
"""
import evdev
from evdev import UInput, ecodes
import select

MAX_SPEED = 5
DAMPING = 0.6

kbd = evdev.InputDevice("/dev/input/event0")
tp = evdev.InputDevice("/dev/input/event3")
tp.grab()

cap = {
    ecodes.EV_KEY: [ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE],
    ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y, ecodes.REL_WHEEL, ecodes.REL_WHEEL_HI_RES],
}
vmouse = UInput(cap, name="virtual-trackpoint")

def clamp(val, limit):
    if val > limit: return limit
    if val < -limit: return -limit
    return val

def dampen(val):
    if abs(val) <= 1: return val
    return int(val * DAMPING) or (1 if val > 0 else -1)

while True:
    r, _, _ = select.select([kbd, tp], [], [])
    for dev in r:
        for event in dev.read():
            if dev == kbd:
                if event.type == ecodes.EV_KEY and event.code in (ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE):
                    vmouse.write(ecodes.EV_KEY, event.code, event.value)
                    vmouse.syn()
            elif dev == tp:
                if event.type == ecodes.EV_REL:
                    if event.code in (ecodes.REL_X, ecodes.REL_Y):
                        vmouse.write(ecodes.EV_REL, event.code, clamp(dampen(event.value), MAX_SPEED))
                    else:
                        vmouse.write(ecodes.EV_REL, event.code, event.value)
                    vmouse.syn()
                elif event.type == ecodes.EV_KEY:
                    vmouse.write(ecodes.EV_KEY, event.code, event.value)
                    vmouse.syn()
