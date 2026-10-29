#!/usr/bin/env python3
"""Waybar custom module: keyboard layout with flag. Listens on Hyprland's event socket."""
import json, os, socket, subprocess, sys

LAYOUTS = {  # matched against the start of Hyprland's layout name
    "English": ("\U0001F1FA\U0001F1F8", "EN"),
    "Arabic":  ("\U0001F1F8\U0001F1E6", "AR"),
}

def emit(name):
    flag, code = next((v for k, v in LAYOUTS.items() if name.startswith(k)), ("⌨", name[:2].upper()))
    print(json.dumps({"text": f"{flag}  {code}", "tooltip": f"{name}\nCaps Lock or click to switch",
                      "class": code.lower()}), flush=True)

def current():
    kbs = json.loads(subprocess.check_output(["hyprctl", "devices", "-j"]))["keyboards"]
    main = next((k for k in kbs if k.get("main")), kbs[0])
    return main["active_keymap"]

emit(current())
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock")
buf = b""
while chunk := sock.recv(4096):
    buf += chunk
    *lines, buf = buf.split(b"\n")
    for line in lines:
        if line.startswith(b"activelayout>>"):
            emit(line.decode(errors="replace").split(",", 1)[-1])
