#!/usr/bin/env python3
"""Pick the fastest Twitch ingest, save it in the active OBS profile, then start OBS.

--no-launch: test and save only.  --self-test: run the checks below, no network.
Any failure keeps the saved server and still starts OBS, so going live is never blocked.
"""
import json
import os
import re
import socket
import statistics
import subprocess
import sys
import tempfile
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SAMPLES = 10
OBS_DIR = Path.home() / ".config/obs-studio"
INGEST_API = "https://ingest.twitch.tv/ingests"
# The API response ends up in a config OBS connects to, so only accept Twitch's own hosts.
INGEST_URL = re.compile(r"rtmp://[a-z0-9-]+\.contribute\.live-video\.net/app/\{stream_key\}")


def parse_ingests(data):
    """Return {name: url template}, without the geo-routed Default, whose host isn't one fixed server."""
    return {
        i["name"]: i["url_template"]
        for i in data["ingests"]
        if i["name"] != "Default" and INGEST_URL.fullmatch(i["url_template"])
    }


def probe(url):
    """TCP connect times to the RTMP port, in ms, the same check OBS's first connect depends on."""
    host = url.split("/")[2]
    times = []
    for _ in range(SAMPLES):
        start = time.perf_counter()
        try:
            socket.create_connection((host, 1935), timeout=2).close()
            times.append((time.perf_counter() - start) * 1000)
        except OSError:
            pass
        time.sleep(0.2)
    return times


def pick_best(results):
    """Lowest median among servers that answered most probes; None if none did."""
    usable = {n: statistics.median(t) for n, t in results.items() if len(t) > SAMPLES / 2}
    return min(usable, key=usable.get) if usable else None


def service_file():
    ini = (OBS_DIR / "user.ini").read_text()
    return OBS_DIR / "basic/profiles" / re.search(r"^ProfileDir=(.+)$", ini, re.M)[1] / "service.json"


def save_server(path, url):
    """Change only the server, and replace the file atomically: it holds the stream key."""
    config = json.loads(path.read_text())
    if config["settings"].get("service") != "Twitch":
        raise ValueError(f"{path} is not set to the Twitch service")
    config["settings"]["server"] = url
    fd, tmp = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            os.fchmod(f.fileno(), path.stat().st_mode & 0o777)
            json.dump(config, f, indent=4)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def choose_and_save():
    """Return a one-line result for the notification."""
    with urllib.request.urlopen(INGEST_API, timeout=5) as response:
        ingests = parse_ingests(json.load(response))
    with ThreadPoolExecutor(len(ingests)) as pool:
        results = dict(zip(ingests, pool.map(probe, ingests.values())))
    for name, times in sorted(results.items(), key=lambda r: statistics.median(r[1] or [1e9])):
        print(f"{statistics.median(times or [0]):7.1f} ms  {len(times):>2}/{SAMPLES}  {name}")
    best = pick_best(results)
    if not best:
        raise OSError("no Twitch server answered")
    save_server(service_file(), ingests[best].removesuffix("/{stream_key}"))
    return f"{best}: {statistics.median(results[best]):.0f} ms"


def self_test():
    assert pick_best({"far": [90.0] * 10, "near": [20.0] * 10}) == "near"
    assert pick_best({"flaky": [1.0] * 5, "steady": [50.0] * 10}) == "steady"
    assert pick_best({"down": []}) is None

    good = "rtmp://aps30.contribute.live-video.net/app/{stream_key}"
    ingests = parse_ingests({"ingests": [
        {"name": "Default", "url_template": "rtmp://ingest.global-contribute.live-video.net/app/{stream_key}"},
        {"name": "Evil", "url_template": "rtmp://evil.example.com/app/{stream_key}"},
        {"name": "Mumbai", "url_template": good},
    ]})
    assert ingests == {"Mumbai": good}

    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "service.json"
        path.write_text(json.dumps({"type": "rtmp_common", "settings": {"service": "Twitch", "key": "k", "server": "old"}}))
        path.chmod(0o600)
        save_server(path, "new")
        settings = json.loads(path.read_text())["settings"]
        assert settings == {"service": "Twitch", "key": "k", "server": "new"}
        assert path.stat().st_mode & 0o777 == 0o600

        path.write_text(json.dumps({"settings": {"service": "YouTube", "server": "old"}}))
        try:
            save_server(path, "new")
            raise AssertionError("overwrote a non-Twitch service")
        except ValueError:
            pass
        assert json.loads(path.read_text())["settings"]["server"] == "old"
    print("ok")


def main():
    if "--self-test" in sys.argv:
        return self_test()
    # A running OBS rewrites service.json on exit, so saving now would be lost; it also only reads it at startup.
    running = subprocess.run(["pgrep", "-x", "obs"], capture_output=True).returncode == 0
    if not running:
        try:
            message = choose_and_save()
        except (OSError, ValueError, KeyError, TypeError) as e:
            message = f"Kept the saved server: {e}"
        print(message)
        subprocess.run(["notify-send", "-a", "OBS", "Twitch server", message], check=False)
    if "--no-launch" not in sys.argv:
        os.execvpe("obs", ["obs"], os.environ | {"QT_QPA_PLATFORM": "xcb"})


if __name__ == "__main__":
    main()
