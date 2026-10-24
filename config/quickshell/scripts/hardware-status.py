#!/usr/bin/env python3
"""
Lightweight hardware & privacy status helper for Quickshell:
  hardware-status.py privacy
  hardware-status.py storage
  hardware-status.py bt-battery
"""
import glob
import json
import os
import re
import subprocess
import sys


def run_cmd(cmd, timeout=3):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return res.stdout if res.returncode == 0 else ""
    except Exception:
        return ""


def cmd_privacy():
    mic_apps = []
    cam_apps = []
    screen_apps = []

    raw = run_cmd(["pw-dump"])
    if raw:
        try:
            objs = json.loads(raw)
            for o in objs:
                if o.get("type") != "PipeWire:Interface:Node":
                    continue
                info = o.get("info") or {}
                state = info.get("state")
                if state != "running":
                    continue
                props = info.get("props") or {}
                media_class = props.get("media.class", "")
                app_name = (
                    props.get("application.name")
                    or props.get("node.description")
                    or props.get("media.name")
                    or props.get("node.name")
                    or "Application"
                )
                node_name = props.get("node.name", "")

                # Ignore internal monitors / peak meters if any
                if node_name in ("quickshell", "pavucontrol") and "peak" in (props.get("media.name", "").lower()):
                    continue

                if media_class == "Stream/Input/Audio":
                    # Check if capturing from a monitor sink (system audio) vs real microphone
                    is_monitor = str(props.get("stream.capture.sink", "")).lower() == "true"
                    if not is_monitor:
                        if app_name not in mic_apps:
                            mic_apps.append(app_name)
                elif media_class == "Stream/Input/Video":
                    # Could be screen share (portal / xdg-desktop-portal-hyprland / wf-recorder) or camera
                    target = (
                        str(props.get("target.object", ""))
                        + " "
                        + str(props.get("media.name", ""))
                        + " "
                        + str(props.get("node.name", ""))
                    ).lower()
                    if "camera" in target or "v4l2" in target or "libcamera" in target:
                        if app_name not in cam_apps:
                            cam_apps.append(app_name)
                    else:
                        if app_name not in screen_apps:
                            screen_apps.append(app_name)
                elif media_class == "Video/Source":
                    # Active V4L2/PipeWire camera source node running
                    desc = props.get("node.description") or props.get("node.nick") or "Camera"
                    if desc not in cam_apps:
                        cam_apps.append(desc)
        except Exception:
            pass

    # Also check /dev/video* directly via /proc/[pid]/fd for non-PipeWire V4L2 apps
    video_devs = set(glob.glob("/dev/video*"))
    if video_devs:
        for fd_dir in glob.glob("/proc/[0-9]*/fd"):
            try:
                pid = fd_dir.split("/")[2]
                for fd in os.listdir(fd_dir):
                    target = os.readlink(os.path.join(fd_dir, fd))
                    if target in video_devs:
                        comm_path = f"/proc/{pid}/comm"
                        if os.path.exists(comm_path):
                            with open(comm_path, "r", encoding="utf-8", errors="ignore") as f:
                                comm = f.read().strip()
                            if comm and comm not in ("pipewire", "wireplumber") and comm not in cam_apps:
                                cam_apps.append(comm)
            except Exception:
                continue

    print(json.dumps({
        "mic": mic_apps,
        "camera": cam_apps,
        "screenshare": screen_apps,
    }))


def format_size(num_bytes):
    try:
        b = float(num_bytes)
    except Exception:
        return ""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if b < 1024.0 or unit == "TB":
            return f"{b:.1f} {unit}" if unit not in ("B", "KB") else f"{int(b)} {unit}"
        b /= 1024.0
    return ""


def cmd_storage():
    raw = run_cmd(["lsblk", "-J", "-b", "-o", "NAME,LABEL,PARTLABEL,RM,HOTPLUG,TYPE,SIZE,MOUNTPOINT,FSTYPE,MODEL,TRAN,PATH"])
    drives = []
    if raw:
        try:
            data = json.loads(raw)

            def walk(dev, parent_info=None):
                is_rem = bool(dev.get("rm")) or bool(dev.get("hotplug")) or (dev.get("tran") in ("usb", "mmc"))
                if parent_info and parent_info.get("is_rem"):
                    is_rem = True
                model = (dev.get("model") or (parent_info or {}).get("model") or "").strip()
                tran = dev.get("tran") or (parent_info or {}).get("tran") or ""
                disk_path = dev.get("path") if dev.get("type") == "disk" else (parent_info or {}).get("disk_path", dev.get("path"))

                children = dev.get("children") or []
                info = {"is_rem": is_rem, "model": model, "tran": tran, "disk_path": disk_path}

                name = dev.get("name") or ""
                if name.startswith("zram") or name.startswith("loop"):
                    return

                fstype = dev.get("fstype") or ""
                dev_type = dev.get("type") or ""
                if is_rem and (dev_type == "part" or (dev_type == "disk" and not children and fstype)):
                    if fstype not in ("swap", ""):
                        label = dev.get("label") or dev.get("partlabel") or model or name
                        drives.append({
                            "name": name,
                            "path": dev.get("path") or f"/dev/{name}",
                            "diskPath": disk_path or f"/dev/{name}",
                            "label": label,
                            "model": model,
                            "tran": tran,
                            "fstype": fstype,
                            "size": format_size(dev.get("size") or 0),
                            "mountpoint": dev.get("mountpoint") or "",
                            "mounted": bool(dev.get("mountpoint")),
                        })

                for ch in children:
                    walk(ch, info)

            for d in data.get("blockdevices") or []:
                walk(d, None)
        except Exception:
            pass
    print(json.dumps(drives))


def cmd_bt_battery():
    out = run_cmd(["upower", "-d"])
    batteries = {}
    if out:
        for block in out.split("\n\n"):
            mac_m = re.search(r"(?:serial|native-path):\s*.*?([0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5})", block)
            pct_m = re.search(r"percentage:\s*(\d+)%", block)
            if mac_m and pct_m:
                mac = mac_m.group(1).replace("_", ":").upper()
                batteries[mac] = int(pct_m.group(1))
    print(json.dumps(batteries))


if __name__ == "__main__":
    sub = sys.argv[1] if len(sys.argv) > 1 else "privacy"
    if sub == "privacy":
        cmd_privacy()
    elif sub == "storage":
        cmd_storage()
    elif sub == "bt-battery":
        cmd_bt_battery()
