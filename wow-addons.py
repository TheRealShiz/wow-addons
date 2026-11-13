#!/usr/bin/env python3
"""
wow-addons: keep CurseForge-hosted WoW addons current for one client flavor
(built for WoW: Forever, works for any flavor CurseForge tags).

  wow-addons.py update        install missing addons, update outdated ones
  wow-addons.py status        show installed vs. latest, change nothing
  wow-addons.py check         like status, exit 10 if anything is outdated
  wow-addons.py versions      list CurseForge's WoW game-version types (debug)

Config:  ~/.config/wow-addons/config.toml
API key: ~/.config/wow-addons/api_key   (chmod 600)  or env CURSEFORGE_API_KEY
State:   ~/.local/state/wow-addons/state.json

Python 3.11+, standard library only.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import shutil
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

API_BASE = os.environ.get("CF_API_BASE", "https://api.curseforge.com")
WOW_GAME_ID = 1
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "wow-addons"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "wow-addons"
CONFIG_PATH = CONFIG_DIR / "config.toml"
KEY_PATH = CONFIG_DIR / "api_key"
STATE_PATH = STATE_DIR / "state.json"

# CurseForge releaseType: 1 = release, 2 = beta, 3 = alpha
CHANNELS = {"release": {1}, "beta": {1, 2}, "alpha": {1, 2, 3}}


# --------------------------------------------------------------------------- helpers

def log(msg: str) -> None:
    print(msg, flush=True)


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr, flush=True)
    sys.exit(code)


def load_api_key() -> str:
    key = os.environ.get("CURSEFORGE_API_KEY", "").strip()
    if not key and KEY_PATH.exists():
        key = KEY_PATH.read_text().strip()
    if not key:
        die(f"no API key: put it in {KEY_PATH} (chmod 600) or set CURSEFORGE_API_KEY")
    return key


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        die(f"missing config: {CONFIG_PATH}")
    with CONFIG_PATH.open("rb") as f:
        cfg = tomllib.load(f)
    if "addons_dir" not in cfg:
        die("config needs addons_dir")
    cfg["addons_dir"] = Path(os.path.expanduser(cfg["addons_dir"]))
    cfg.setdefault("flavor", "Forever")
    cfg.setdefault("channel", "release")
    cfg.setdefault("addons", [])
    if cfg["channel"] not in CHANNELS:
        die(f"channel must be one of {sorted(CHANNELS)}")
    return cfg


def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text())
    return {"addons": {}}


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(STATE_PATH)


class CurseForge:
    def __init__(self, key: str):
        self.key = key

    def _get(self, path: str, params: dict | None = None, raw: bool = False):
        url = API_BASE + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={
            "x-api-key": self.key,
            "Accept": "application/json",
            "User-Agent": "wow-addons/1.0",
        })
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    body = r.read()
                return body if raw else json.loads(body)
            except urllib.error.HTTPError as e:
                if e.code == 403:
                    die("CurseForge rejected the API key (403)")
                if e.code in (429, 500, 502, 503, 504) and attempt < 2:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise
            except urllib.error.URLError:
                if attempt < 2:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise

    def version_types(self) -> list[dict]:
        return self._get(f"/v1/games/{WOW_GAME_ID}/version-types")["data"]

    def find_slug(self, slug: str) -> dict | None:
        data = self._get("/v1/mods/search", {"gameId": WOW_GAME_ID, "slug": slug})["data"]
        for mod in data:
            if mod.get("slug") == slug:
                return mod
        return None

    def mod(self, mod_id: int) -> dict:
        return self._get(f"/v1/mods/{mod_id}")["data"]

    def files(self, mod_id: int, version_type_id: int) -> list[dict]:
        return self._get(f"/v1/mods/{mod_id}/files",
                         {"gameVersionTypeId": version_type_id, "pageSize": 50})["data"]

    def download(self, f: dict) -> bytes:
        url = f.get("downloadUrl")
        if not url:
            # The author has opted out of third-party distribution; respect that.
            raise PermissionError("author does not allow third-party downloads - install this one manually")
        req = urllib.request.Request(url, headers={"User-Agent": "wow-addons/1.0"})
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()


# --------------------------------------------------------------------------- logic
# CurseForge's API terms forbid caching API data, so lookups are repeated each run;
# state.json only records what this script installed locally.

def resolve_version_type(cf: CurseForge, flavor: str, state: dict) -> int:
    want = flavor.lower()
    types = cf.version_types()
    match = [t for t in types if want in t.get("name", "").lower() or want == t.get("slug", "").lower()]
    if len(match) != 1:
        names = ", ".join(f"{t['id']}={t['name']}" for t in types)
        die(f"could not pick one version type for flavor '{flavor}'. Set version_type_id in config. Known: {names}")
    return match[0]["id"]


def resolve_mod_id(cf: CurseForge, entry, state: dict) -> tuple[int, str]:
    """entry: slug string, numeric id, or {slug=..} / {id=..} table."""
    if isinstance(entry, dict):
        entry = entry.get("id") or entry.get("slug")
    if isinstance(entry, int) or (isinstance(entry, str) and entry.isdigit()):
        return int(entry), str(entry)
    slug = str(entry)
    mod = cf.find_slug(slug)
    if not mod:
        raise LookupError(f"no WoW addon with slug '{slug}'")
    return mod["id"], slug


def pick_latest(files: list[dict], channel: str) -> dict | None:
    allowed = CHANNELS[channel]
    ok = [f for f in files if f.get("releaseType") in allowed and f.get("isAvailable", True)]
    ok.sort(key=lambda f: (f.get("fileDate", ""), f["id"]), reverse=True)
    return ok[0] if ok else None


def top_level_dirs(zf: zipfile.ZipFile) -> list[str]:
    tops = set()
    for name in zf.namelist():
        parts = Path(name).parts
        if not parts or parts[0] in ("", ".", "..") or Path(name).is_absolute():
            raise ValueError(f"unsafe path in zip: {name}")
        if ".." in parts:
            raise ValueError(f"unsafe path in zip: {name}")
        if len(parts) > 1 or name.endswith("/"):
            tops.add(parts[0])
    if not tops:
        raise ValueError("zip has no addon folders")
    return sorted(tops)


def install_zip(data: bytes, addons_dir: Path, old_dirs: list[str]) -> list[str]:
    zf = zipfile.ZipFile(io.BytesIO(data))
    new_dirs = top_level_dirs(zf)
    addons_dir.mkdir(parents=True, exist_ok=True)
    # Extract to a staging dir on the same filesystem, then swap folders in.
    with tempfile.TemporaryDirectory(dir=addons_dir.parent, prefix=".wow-addons-") as stage:
        zf.extractall(stage)
        for d in set(old_dirs) | set(new_dirs):
            target = addons_dir / d
            if target.exists() or target.is_symlink():
                shutil.rmtree(target) if target.is_dir() and not target.is_symlink() else target.unlink()
        for d in new_dirs:
            shutil.move(os.path.join(stage, d), addons_dir / d)
    return new_dirs


def run(cmd: str) -> int:
    cfg = load_config()
    state = load_state()
    cf = CurseForge(load_api_key())

    if cmd == "versions":
        for t in cf.version_types():
            log(f"{t['id']:>8}  {t.get('slug', ''):<24} {t.get('name', '')}")
        return 0

    vt = cfg.get("version_type_id") or resolve_version_type(cf, cfg["flavor"], state)
    addons_dir: Path = cfg["addons_dir"]
    if not addons_dir.parent.exists():
        die(f"{addons_dir.parent} does not exist - check addons_dir")

    outdated = failures = changed = 0
    for entry in cfg["addons"]:
        try:
            mod_id, label = resolve_mod_id(cf, entry, state)
            files = cf.files(mod_id, vt)
            latest = pick_latest(files, cfg["channel"])
            if not latest:
                log(f"  -- {label}: no {cfg['flavor']} {cfg['channel']} file on CurseForge")
                continue
            have = state["addons"].get(str(mod_id), {})
            missing = any(not (addons_dir / d).is_dir() for d in have.get("dirs", [])) or not have
            if have.get("file_id") == latest["id"] and not missing:
                if cmd != "update":
                    log(f"  ok {label}: {latest['displayName']}")
                continue
            outdated += 1
            was = have.get("display", "not installed")
            if cmd != "update":
                log(f"  ^^ {label}: {was} -> {latest['displayName']}")
                continue
            data = cf.download(latest)
            dirs = install_zip(data, addons_dir, have.get("dirs", []))
            state["addons"][str(mod_id)] = {
                "label": label,
                "file_id": latest["id"],
                "display": latest["displayName"],
                "dirs": dirs,
                "installed_at": int(time.time()),
            }
            save_state(state)
            changed += 1
            log(f"  ++ {label}: {was} -> {latest['displayName']}")
        except Exception as e:  # keep going; one bad addon shouldn't block the rest
            failures += 1
            log(f"  !! {entry}: {e}")

    save_state(state)
    log(f"{changed} updated, {failures} failed" if cmd == "update"
        else f"{outdated} outdated, {failures} failed")
    if failures:
        return 1
    if cmd == "check" and outdated:
        return 10
    return 0


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", nargs="?", default="update", choices=["update", "status", "check", "versions"])
    sys.exit(run(p.parse_args().command))


if __name__ == "__main__":
    main()
