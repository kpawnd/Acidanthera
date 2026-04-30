# Atherion

macOS lab setup automation for Intel iMacs running Ventura and later.

## Full setup

**With git:**
```shell
git clone https://github.com/kpawnd/Atherion.git && cd Atherion && sudo bash main.sh
```

**Without git** (GitHub tarball — no git required):
```shell
curl -fsSL https://github.com/kpawnd/Atherion/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && sudo bash /tmp/Atherion-main/main.sh
```

GitHub serves the entire repo as a tarball at that URL, so all scripts are present on disk and the relative `source` calls inside `main.sh` resolve correctly.

## Wallpaper / lock screen only

**Without git** (recommended — works anywhere):
```shell
curl -fsSL https://github.com/kpawnd/Atherion/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && sudo bash -c 'source /tmp/Atherion-main/scripts/lib/core/ui.sh && source /tmp/Atherion-main/scripts/lib/system/lockscreen_config.sh && configure_lockscreen_background'
```

**From inside the cloned repo:**
```shell
sudo bash -c 'source scripts/lib/core/ui.sh && source scripts/lib/system/lockscreen_config.sh && configure_lockscreen_background'
```

To use a custom image URL, prepend `LOCKSCREEN_IMAGE_URL="https://…"` to either command:

```shell
curl -fsSL https://github.com/kpawnd/Atherion/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && sudo bash -c 'LOCKSCREEN_IMAGE_URL="https://example.com/your-image.png" source /tmp/Atherion-main/scripts/lib/core/ui.sh && source /tmp/Atherion-main/scripts/lib/system/lockscreen_config.sh && configure_lockscreen_background'
```

Changes take effect on the next lock screen or reboot — no logout required.

## Local overrides

Copy `.env.example` to `.env` (gitignored) before running. Supported variables:

| Variable | Purpose |
|---|---|
| `PACKET_TRACER_DMG_URL` | Direct DMG URL for Cisco Packet Tracer (SharePoint links supported) |
| `LOCKSCREEN_IMAGE_URL` | Custom wallpaper/lock screen image URL |
| `LOCKSCREEN_REPLACE_SYSTEM` | `1` (default) replaces `/System/Library/Desktop Pictures/<release>.heic` so the cold-boot login screen actually changes — only runs when SIP and authenticated-root are both disabled (OCLP). Set `0` to skip. |
| `LOCKSCREEN_SET_WALLPAPER` | `1` (default) sets each local user's desktop wallpaper. Set `0` to skip. |
| `NO_PROGRESS` | Set `1` to suppress the live spinner — stage transitions print as plain log lines instead. Use when teeing output to a log or running unattended. |
| `RELEASES_REPO` | Override GitHub repo used to resolve release assets |
| `BLENDER_DMG_URL` / `BLENDER_VERSION` | Override Blender download URL and version |

### What gets changed where

macOS has three distinct "lock-related" screens; this script configures each through the only mechanism that actually works for it on Sequoia:

| Screen | Mechanism | Notes |
|---|---|---|
| Cold-boot login screen (after restart/shutdown) | Replaces `/System/Library/Desktop Pictures/<release>.heic` directly | OCLP machines only (SIP + authenticated-root both disabled). Reverted by OCLP root-patch re-application — re-run the lockscreen step after each OCLP patch. |
| Login window after logout / switch-user | Sets each local user's desktop wallpaper (the login window shows the previously-active user's) | Works on Monterey → Sequoia |
| Per-user lock screen (⌃⌘Q, idle lock) | Writes `/Library/Caches/Desktop Pictures/<GUID>/lockscreen.png` for each user | Works on Monterey → Sequoia |

Pre-Big-Sur tricks (writing `DesktopPicture`/`LockScreenImage` to `com.apple.loginwindow.plist`, `RunAtLoad` daemons that restore those plists, `/private/var/db/loginwindow/...`) are no longer honored on Sequoia and have been removed.
