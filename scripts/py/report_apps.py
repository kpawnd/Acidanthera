#!/usr/bin/env python3
import plistlib
from pathlib import Path

APPS = [
    ("Azure Data Studio", Path("/Applications/Azure Data Studio.app")),
    ("Blender", Path("/Applications/Blender.app")),
    ("Android Studio", Path("/Applications/Android Studio.app")),
]


def app_version(app_path: Path) -> str:
    plist_path = app_path / "Contents" / "Info.plist"
    if not plist_path.exists():
        return "unknown"

    try:
        with plist_path.open("rb") as f:
            data = plistlib.load(f)
    except Exception:
        return "unknown"

    return data.get("CFBundleShortVersionString") or data.get("CFBundleVersion") or "unknown"


for app_name, app_path in APPS:
    if app_path.exists():
        print(f"{app_name}|installed|{app_version(app_path)}")
    else:
        print(f"{app_name}|not_installed|-")
