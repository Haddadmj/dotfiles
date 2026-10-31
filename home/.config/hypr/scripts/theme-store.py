#!/usr/bin/env python3
# Search Pling (gnome-look.org) for cursor and icon themes and install them for this user.
# Backend of the Quickshell theme browser (launcher/ThemeBrowser.qml). Prints one JSON object.
#   theme-store.py search cursor|icons <query> <page>
#   theme-store.py install cursor|icons <pling id> <file number>
#   theme-store.py remove <theme name>
#   theme-store.py selftest
#
# Uploads are not reviewed, so an archive is only ever data: nothing in it is run, unsafe paths
# refuse the whole archive, and only files a theme needs reach ~/.local/share/icons, never executable.
import hashlib, json, os, re, shutil, stat, subprocess, sys, tarfile, tempfile, zipfile
from pathlib import Path, PurePosixPath
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

API = "https://api.pling.com/ocs/v1/content/data"
CATEGORIES = {"cursor": "107", "icons": "132"}
PAGE_SIZE = 24
USER_AGENT = "quickshell-theme-browser"
ARCHIVE = re.compile(r"\.(tar(\.\w+)?|tgz|txz|tbz2?|zip)$", re.I)
ARCHIVE_MIME = re.compile(r"mimetype=application/(x-)?(tar|gzip|xz|bzip2?|zstd|gtar|zip|compressed-tar|xz-compressed-tar|bzip-compressed-tar)", re.I)
THEME_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+ -]{0,63}$")   # also keeps appearance.sh's sed safe
ICON_FILE = re.compile(r"\.(svg|svgz|png|xpm)$", re.I)
XCURSOR_MAGIC = b"Xcur"
CDN_HOST = re.compile(r"^ocs-dl\.[a-z0-9]+\.cdn\.digitaloceanspaces\.com$")

# plenty for a real theme, stops decompression bombs
MAX_DOWNLOAD = 300 * 1024 * 1024
MAX_UNPACKED = 2 * 1024 * 1024 * 1024
MAX_ENTRIES = 300_000


class StoreError(Exception):
    pass


class AlreadyInstalled(StoreError):
    def __init__(self, message, names):
        super().__init__(message)
        self.names = names


def store_dir():
    return Path.home() / ".local/share/theme-store"


def icons_dir():
    return Path.home() / ".local/share/icons"


def trusted_host(url):
    parts = urlsplit(url)
    host = parts.hostname or ""
    # Pling's download links redirect to its file CDN
    return parts.scheme == "https" and (host.endswith((".pling.com", ".opendesktop.org")) or CDN_HOST.match(host) is not None)


class CheckRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not trusted_host(newurl):
            raise StoreError(f"download redirected to an unexpected host: {urlsplit(newurl).hostname}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url):
    if not trusted_host(url):
        raise StoreError(f"refusing to download from {urlsplit(url).hostname}")
    return build_opener(CheckRedirects).open(Request(url, headers={"User-Agent": USER_AGENT}), timeout=30)


def api_get(url):
    with fetch(url) as response:
        data = json.load(response)
    if data.get("status") != "ok":
        raise StoreError(data.get("message") or "Pling returned an error")
    return data


def installable_files(item):
    files = []
    for i in range(1, 100):
        name, link = item.get(f"downloadname{i}"), item.get(f"downloadlink{i}")
        if not name or not link or not trusted_host(link):
            continue
        tags = str(item.get(f"downloadtags{i}") or "")
        # Windows cursor packs and source bitmaps aren't installable themes
        if re.search(r"windows|bitmaps", name, re.I) or not (ARCHIVE.search(name) or ARCHIVE_MIME.search(tags)):
            continue
        files.append({"number": i, "name": name, "size": int(item.get(f"downloadsize{i}") or 0)})
    return files


def previews(item):
    pics = (item.get(f"previewpic{i}") for i in range(1, 7))
    return [p for p in pics if p and p.startswith("https://images.pling.com/")]


def load_manifest():
    try:
        return json.loads((store_dir() / "installed.json").read_text())
    except FileNotFoundError:
        return {}


def save_manifest(manifest):
    store_dir().mkdir(parents=True, exist_ok=True)
    tmp = store_dir() / "installed.json.tmp"
    tmp.write_text(json.dumps(manifest, indent=1))
    tmp.replace(store_dir() / "installed.json")


def search(kind, query, page):
    params = {"format": "json", "categories": CATEGORIES[kind], "sortmode": "high", "pagesize": PAGE_SIZE, "page": int(page)}
    if query:
        params["search"] = query
    data = api_get(f"{API}?{urlencode(params)}")
    items = []
    for item in data.get("data", []):
        files = installable_files(item)
        if not files or item.get("ghns_excluded"):
            continue
        items.append({
            "id": str(item["id"]),
            "name": str(item.get("name") or ""),
            "author": str(item.get("personid") or ""),
            "score": int(item.get("score") or 0),
            "downloads": int(item.get("downloads") or 0),
            "previews": previews(item),
            "page": item.get("detailpage") or "",
            "files": files,
        })
    return {"total": int(data.get("totalitems") or 0), "pageSize": PAGE_SIZE, "items": items, "installed": load_manifest()}


def safe_parts(name):
    """Path of an archive entry as parts inside the archive; refuses anything that could leave it."""
    path = PurePosixPath(name)
    if "\\" in name or "\0" in name or path.is_absolute() or ".." in path.parts:
        raise StoreError(f"unsafe path in archive: {name!r}")
    return path.parts


def archive_entries(path):
    """Yield (name, kind, size, read) with kind file/dir/link. read() gives a stream, or the target for links."""
    if tarfile.is_tarfile(path):
        with tarfile.open(path, "r:*") as tar:
            for m in tar:
                if m.isreg():
                    yield m.name, "file", m.size, lambda m=m: tar.extractfile(m)
                elif m.isdir():
                    yield m.name, "dir", 0, None
                elif m.issym():
                    yield m.name, "link", 0, lambda m=m: m.linkname
                # hard links, devices and fifos are never part of a theme we want
    elif zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as zf:
            for i in zf.infolist():
                if stat.S_ISLNK(i.external_attr >> 16):
                    yield i.filename, "link", 0, lambda i=i: zf.read(i).decode("utf-8", "replace") if i.file_size < 4096 else ""
                elif i.is_dir():
                    yield i.filename, "dir", 0, None
                else:
                    yield i.filename, "file", i.file_size, lambda i=i: zf.open(i)
    else:
        raise StoreError("not a tar or zip archive")


def unpack(path, root):
    entries = total = 0
    links = []
    for name, kind, size, read in archive_entries(path):
        entries += 1
        if entries > MAX_ENTRIES:
            raise StoreError("archive has too many files")
        parts = safe_parts(name)
        if not parts or parts == (".",):
            continue
        dest = root.joinpath(*parts)
        if kind == "dir":
            dest.mkdir(parents=True, exist_ok=True)
        elif kind == "link":
            links.append((dest, read()))
        else:
            total += size
            if total > MAX_UNPACKED:
                raise StoreError("archive is too large when unpacked")
            dest.parent.mkdir(parents=True, exist_ok=True)
            # links are created after every file, so this can't write through one
            with read() as src, open(dest, "wb") as out:
                shutil.copyfileobj(src, out)
    for dest, target in links:
        if not target or target.startswith("/") or "\0" in target or os.path.lexists(dest):
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        if Path(os.path.realpath(dest.parent)) == dest.parent:   # never place a link through another link
            os.symlink(target, dest)


def is_theme(path, kind):
    if kind == "cursor":
        return (path / "cursors").is_dir() or (path / "manifest.hl").is_file() or (path / "manifest.toml").is_file()
    try:
        index = (path / "index.theme").read_text(errors="replace")
    except OSError:
        return False
    return re.search(r"^Directories=", index, re.M) is not None and re.search(r"^Hidden=true", index, re.M) is None


def find_themes(root, kind):
    found = []
    for dirpath, dirnames, _ in os.walk(root):
        if is_theme(Path(dirpath), kind):
            found.append(Path(dirpath))
            dirnames[:] = []
    return found


def wanted_file(rel, source, kind):
    if rel.name.lower() in ("index.theme", "cursor.theme"):
        return True
    if kind == "icons":
        return ICON_FILE.search(rel.name) is not None
    if rel.parts[0] == "cursors":
        with open(source, "rb") as f:
            return f.read(4) == XCURSOR_MAGIC
    return rel.name in ("manifest.hl", "manifest.toml") or (rel.parts[0] == "hyprcursors" and rel.suffix == ".hlc")


def clean_copy(theme, dest, kind):
    """Copy only what the theme needs. Links survive only if they stay inside the theme."""
    links = []
    for dirpath, dirnames, filenames in os.walk(theme):
        here = Path(dirpath)
        for name in dirnames + filenames:
            source = here / name
            rel = source.relative_to(theme)
            if source.is_symlink():
                links.append((rel, os.readlink(source)))
            elif source.is_dir():
                (dest / rel).mkdir(parents=True, exist_ok=True)
            elif source.is_file() and wanted_file(rel, source, kind):
                (dest / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, dest / rel, follow_symlinks=False)
    for rel, target in links:
        (dest / rel).parent.mkdir(parents=True, exist_ok=True)
        os.symlink(target, dest / rel)
    # after the copy, so links to files we left out go too, and links through links are fully resolved
    root = os.path.realpath(dest)
    changed = True
    while changed:
        changed = False
        for dirpath, dirnames, filenames in os.walk(dest):
            for name in dirnames + filenames:
                link = os.path.join(dirpath, name)
                if os.path.islink(link):
                    real = os.path.realpath(link)
                    if not (real == root or real.startswith(root + os.sep)) or not os.path.exists(real):
                        os.unlink(link)
                        changed = True


def theme_exists(name):
    return any(os.path.lexists(d / name) for d in (icons_dir(), Path.home() / ".icons", Path("/usr/share/icons")))


def install_archive(archive, kind, item_id, filename, work):
    unpacked = work / "unpacked"
    unpacked.mkdir()
    unpack(archive, unpacked)
    themes = find_themes(unpacked, kind)
    if not themes:
        raise StoreError(f"no {'cursor' if kind == 'cursor' else 'icon'} theme found in {filename}")

    manifest = load_manifest()
    installed, skipped = [], []
    built = work / "built"
    built.mkdir()
    for theme in themes:
        # a theme at the top of the archive has no folder of its own to name it
        name = ARCHIVE.sub("", filename) if theme == unpacked else theme.name
        ours = manifest.get(name, {}).get("id") == item_id
        if not THEME_NAME.match(name) or name in installed or (theme_exists(name) and not ours):
            skipped.append(name)
            continue
        clean_copy(theme, built / name, kind)
        if not is_theme(built / name, kind) or not any(True for p in (built / name).rglob("*") if p.is_file()):
            shutil.rmtree(built / name)
            skipped.append(name)
            continue
        icons_dir().mkdir(parents=True, exist_ok=True)
        if ours:
            shutil.rmtree(icons_dir() / name)
        os.replace(built / name, icons_dir() / name)
        manifest[name] = {"id": item_id, "kind": kind, "file": filename}
        installed.append(name)
        save_manifest(manifest)
    if not installed:
        existing = [n for n in skipped if THEME_NAME.match(n) and theme_exists(n)]
        raise AlreadyInstalled(f"nothing new to install from {filename}: {', '.join(skipped)} already exists or isn't usable", existing)
    return installed, skipped


def install(kind, item_id, number):
    if not item_id.isdigit():
        raise StoreError("bad theme id")
    item = api_get(f"{API}/{item_id}?format=json")["data"]
    item = item[0] if isinstance(item, list) else item
    if str(item.get("typeid")) != CATEGORIES[kind]:
        raise StoreError("this item is not a theme of that kind")
    files = {f["number"]: f for f in installable_files(item)}
    if int(number) not in files:
        raise StoreError("that file can't be installed")
    filename = files[int(number)]["name"]
    if "/" in filename or "\0" in filename:
        raise StoreError("bad file name")

    store_dir().mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="install-", dir=store_dir()))
    try:
        archive = work / "download"
        digest, size = hashlib.md5(usedforsecurity=False), 0
        with fetch(item[f"downloadlink{number}"]) as response, open(archive, "wb") as out:
            while chunk := response.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_DOWNLOAD:
                    raise StoreError("download is too large")
                digest.update(chunk)
                out.write(chunk)
        expected = item.get(f"downloadmd5sum{number}")
        if expected and digest.hexdigest() != expected:
            raise StoreError("download is corrupt (checksum mismatch)")
        try:
            installed, skipped = install_archive(archive, kind, item_id, filename, work)
        except AlreadyInstalled as e:
            if not e.names:
                raise
            return {"themes": [], "existing": e.names, "installed": load_manifest()}
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return {"themes": installed, "skipped": skipped, "installed": load_manifest()}


def active_theme(kind):
    if kind == "cursor":
        try:
            return (Path.home() / ".config/hypr/cursor-theme").read_text().strip()
        except FileNotFoundError:
            return ""
    out = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], capture_output=True, text=True)
    return out.stdout.strip().strip("'")


def remove(name):
    manifest = load_manifest()
    if name not in manifest or not THEME_NAME.match(name):
        raise StoreError(f"{name} wasn't installed from the theme browser")
    if active_theme(manifest[name]["kind"]) == name:
        raise StoreError(f"{name} is in use, switch to another theme first")
    shutil.rmtree(icons_dir() / name, ignore_errors=True)
    del manifest[name]
    save_manifest(manifest)
    return {"removed": name, "installed": load_manifest()}


def selftest():
    global MAX_UNPACKED
    import io

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        os.environ["HOME"] = str(tmp / "home")
        outside = tmp / "outside"
        outside.mkdir()
        (outside / "secret").write_text("x")
        count = [0]

        def make_tar(*entries):
            count[0] += 1
            path = tmp / f"a{count[0]}.tar.gz"
            with tarfile.open(path, "w:gz") as tar:
                for name, value in entries:
                    info = tarfile.TarInfo(name)
                    if isinstance(value, tuple):   # ("sym" | "fifo", target)
                        info.type = tarfile.SYMTYPE if value[0] == "sym" else tarfile.FIFOTYPE
                        info.linkname = value[1]
                        tar.addfile(info)
                    else:
                        info.size = len(value)
                        info.mode = 0o4755
                        tar.addfile(info, io.BytesIO(value))
            return path

        def run(archive, kind="cursor", item="1", filename="a.tar.gz"):
            work = tmp / f"work{count[0]}-{len(list(tmp.iterdir()))}"
            work.mkdir()
            return install_archive(archive, kind, item, filename, work)

        def refused(archive, needle):
            try:
                run(archive)
            except StoreError as e:
                assert needle in str(e), e
                return
            raise AssertionError(f"expected refusal: {needle}")

        cursor = b"Xcur-data"
        names, _ = run(make_tar(
            ("Good/index.theme", b"[Icon Theme]\nName=Good\n"),
            ("Good/cursors/left_ptr", cursor),
            ("Good/cursors/default", ("sym", "left_ptr")),
            ("Good/cursors/escape", ("sym", "../../../../outside/secret")),
            ("Good/cursors/abs", ("sym", str(outside / "secret"))),
            ("Good/cursors/fake", b"#!/bin/sh\nrm -rf /\n"),
            ("Good/install.sh", b"#!/bin/sh\nrm -rf /\n"),
            ("Good/pipe", ("fifo", "")),
        ))
        good = icons_dir() / "Good"
        assert names == ["Good"]
        assert (good / "cursors/left_ptr").read_bytes() == cursor
        assert os.readlink(good / "cursors/default") == "left_ptr"
        for dropped in ("cursors/escape", "cursors/abs", "cursors/fake", "install.sh", "pipe"):
            assert not os.path.lexists(good / dropped), dropped
        assert not stat.S_IMODE((good / "cursors/left_ptr").stat().st_mode) & 0o6111, "exec or setuid bit kept"

        refused(make_tar(("../evil/cursors/x", cursor)), "unsafe path")
        refused(make_tar(("/tmp/evil/cursors/x", cursor)), "unsafe path")
        refused(make_tar(("Bad\\..\\x", cursor)), "unsafe path")
        refused(make_tar(("Empty/readme.txt", b"hi")), "no cursor theme")

        # a link followed by a file through it must stay inside the staging folder
        names, _ = run(make_tar(("Through/x", ("sym", str(outside))), ("Through/x/pwned", b"bad"), ("Through/cursors/a", cursor)))
        assert names == ["Through"] and not (outside / "pwned").exists()

        # going up through a shallow link reaches further than the path suggests
        names, _ = run(make_tar(
            ("Chain/cursors/left_ptr", cursor),
            ("Chain/deep/er/up", ("sym", "../..")),
            ("Chain/deep/er/out", ("sym", "up/../../../../outside/secret")),
        ))
        assert not os.path.lexists(icons_dir() / "Chain/deep/er/out")

        zip_path = tmp / "evil.zip"
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("../../zipped", "bad")
        refused(zip_path, "unsafe path")
        assert not (tmp / "zipped").exists()

        zip_path = tmp / "good.zip"
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("Zipped/cursors/left_ptr", cursor)
            link = zipfile.ZipInfo("Zipped/cursors/default")
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            zf.writestr(link, "left_ptr")
        assert run(zip_path)[0] == ["Zipped"]
        assert os.readlink(icons_dir() / "Zipped/cursors/default") == "left_ptr"

        # a theme named by its archive: the filename must also pass the name check
        try:
            run(make_tar(("cursors/left_ptr", cursor)), filename=";rm -rf x.tar.gz")
            raise AssertionError("bad name accepted")
        except StoreError as e:
            assert "nothing new" in str(e)

        limit, MAX_UNPACKED = MAX_UNPACKED, 4
        refused(make_tar(("Big/cursors/left_ptr", cursor)), "too large")
        MAX_UNPACKED = limit

        # someone else's theme of the same name is left alone, our own is replaced on update
        mine = icons_dir() / "Mine/cursors"
        mine.mkdir(parents=True)
        (mine / "left_ptr").write_bytes(b"Xcur-mine")
        refused(make_tar(("Mine/cursors/left_ptr", cursor)), "nothing new")
        assert (mine / "left_ptr").read_bytes() == b"Xcur-mine"
        assert run(make_tar(("Good/cursors/left_ptr", b"Xcur-new")))[0] == ["Good"]
        assert (good / "cursors/left_ptr").read_bytes() == b"Xcur-new"
        assert not (good / "index.theme").exists()

        try:
            remove("Mine")
            raise AssertionError("removed a theme we didn't install")
        except StoreError:
            pass
        assert mine.exists()
        (tmp / "home/.config/hypr").mkdir(parents=True)
        (tmp / "home/.config/hypr/cursor-theme").write_text("Good\n")
        try:
            remove("Good")
            raise AssertionError("removed the theme in use")
        except StoreError:
            pass
        (tmp / "home/.config/hypr/cursor-theme").write_text("Other\n")
        remove("Good")
        assert not good.exists()

        icon_tar = make_tar(
            ("Pack/index.theme", b"[Icon Theme]\nName=Pack\nDirectories=48\n"),
            ("Pack/48/folder.svg", b"<svg/>"),
            ("Pack/48/run.py", b"print(1)"),
            ("Pack/icon-theme.cache", b"binary"),
        )
        assert run(icon_tar, kind="icons")[0] == ["Pack"]
        assert (icons_dir() / "Pack/48/folder.svg").exists()
        assert not (icons_dir() / "Pack/48/run.py").exists() and not (icons_dir() / "Pack/icon-theme.cache").exists()

        assert not trusted_host("http://images.pling.com/x") and not trusted_host("https://pling.com.evil.net/x")
        assert not trusted_host("https://evilpling.com/x") and trusted_host("https://files06.pling.com/x")
        assert trusted_host("https://ocs-dl.fra1.cdn.digitaloceanspaces.com/x") and not trusted_host("https://other.fra1.cdn.digitaloceanspaces.com/x")
    return {"selftest": "ok"}


def main():
    args = sys.argv[1:]
    try:
        if args[:1] == ["search"] and len(args) == 4 and args[1] in CATEGORIES:
            result = search(args[1], args[2], args[3])
        elif args[:1] == ["install"] and len(args) == 4 and args[1] in CATEGORIES:
            result = install(args[1], args[2], args[3])
        elif args[:1] == ["remove"] and len(args) == 2:
            result = remove(args[1])
        elif args == ["selftest"]:
            result = selftest()
        else:
            print("usage: see the top of this file", file=sys.stderr)
            return 2
    except AssertionError:
        raise
    except Exception as e:
        result = {"error": str(e) or type(e).__name__}
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
