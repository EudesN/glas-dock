#!/usr/bin/env python3
"""
Glasbattery — lightweight USB HID peripheral battery reader.
Queries supported wireless 2.4GHz dongles and wired USB mice over /dev/hidraw
and prints a JSON array of detected devices:
  [{"key": "...", "name": "...", "kind": "mouse", "percent": 70, "charging": false}]
"""

import glob
import json
import os
import select

SUPPORTED_DEVICES = [
    {"vid": "1a2c", "pid": "8fff", "mode": "2.4G", "name": "Delux M400", "kind": "mouse"},
    {"vid": "1a2c", "pid": "9046", "mode": "USB",  "name": "Delux M400", "kind": "mouse"},
    {"vid": "3554", "pid": "fb26", "mode": "2.4G", "name": "Delux M400 Pro", "kind": "mouse"},
    {"vid": "3554", "pid": "fb25", "mode": "USB",  "name": "Delux M400 Pro", "kind": "mouse"},
]

MAGIC_HEADER = bytes([0xAA, 0x55, 0xCC, 0x33])


def find_hidraw_devices():
    """Return a list of (dev_spec, hidraw_path) picking interface :1.0 first."""
    candidates = {}
    for h in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        uevent_path = os.path.join(h, "device", "uevent")
        if not os.path.exists(uevent_path):
            continue
        try:
            with open(uevent_path, "r", encoding="utf-8", errors="ignore") as f:
                uevent = f.read().lower()
        except OSError:
            continue

        for dev in SUPPORTED_DEVICES:
            vid, pid = dev["vid"], dev["pid"]
            if f":0000{vid}:0000{pid}" not in uevent and f":{vid}:{pid}" not in uevent:
                continue
            key = f"{vid}:{pid}"
            dev_node = "/dev/" + os.path.basename(h)
            if not os.access(dev_node, os.R_OK | os.W_OK):
                continue
            real_dev = os.path.realpath(os.path.join(h, "device"))
            is_iface0 = (":1.0" in real_dev) or ("input0" in uevent)
            # Keep interface 0 if available; otherwise store first matching fallback.
            if key not in candidates or is_iface0:
                candidates[key] = (dev, dev_node, is_iface0)
                if is_iface0:
                    break
    return [(spec, path) for spec, path, _ in candidates.values()]


def query_delux_battery(spec, hidraw_path, timeout=0.45):
    """Send 65-byte HID battery query and parse AA 55 CC 33 FD <pct> <chg>."""
    report = bytearray(65)
    if spec["mode"] == "2.4G":
        report[1:7] = bytes([0xBB, 0xAA, 0x99, 0x88, 0x09, 0xFD])
    else:
        report[1:3] = bytes([0x08, 0xFD])

    fd = None
    try:
        fd = os.open(hidraw_path, os.O_RDWR | os.O_NONBLOCK)
        os.write(fd, report)
        r_ready, _, _ = select.select([fd], [], [], timeout)
        if not r_ready:
            return None
        resp = os.read(fd, 65)
    except OSError:
        return None
    finally:
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass

    if not resp or len(resp) < 7:
        return None

    for i in range(len(resp) - 6):
        if resp[i:i + 4] == MAGIC_HEADER and resp[i + 4] == 0xFD:
            batt = resp[i + 5]
            chg_code = resp[i + 6]
            if 0 <= batt <= 100:
                # On 2.4GHz Delux receivers (1a2c:8fff), byte 6 is 0x01 during normal
                # wireless operation (discharging). Bit 1 (0x02/0x03) indicates charging
                # over wireless; wired USB mode (1a2c:9046) charges whenever plugged in.
                if spec["mode"] == "2.4G":
                    is_charging = chg_code in (2, 3)
                else:
                    is_charging = chg_code in (1, 2, 3) and batt < 100
                return {
                    "key": f"usb-{spec['vid']}-{spec['pid']}",
                    "name": spec["name"],
                    "kind": spec["kind"],
                    "percent": int(batt),
                    "charging": is_charging,
                }
            return None
    return None


def main():
    results = []
    for spec, hidraw_path in find_hidraw_devices():
        info = query_delux_battery(spec, hidraw_path)
        if info is not None:
            results.append(info)
    print(json.dumps(results))


if __name__ == "__main__":
    main()
