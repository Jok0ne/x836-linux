#!/bin/bash
sleep 3
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
