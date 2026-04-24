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

Run this from inside the cloned repo to set the lock screen and desktop wallpaper without running the full script.

```shell
sudo bash -c 'source scripts/lib/core/ui.sh && source scripts/lib/system/lockscreen_config.sh && configure_lockscreen_background'
```

To use a custom image URL:

```shell
sudo bash -c 'LOCKSCREEN_IMAGE_URL="https://example.com/your-image.png" source scripts/lib/core/ui.sh && source scripts/lib/system/lockscreen_config.sh && configure_lockscreen_background'
```

Changes take effect on the next lock screen or reboot — no logout required.

## Local overrides

Copy `.env.example` to `.env` (gitignored) before running. Supported variables:

| Variable | Purpose |
|---|---|
| `PACKET_TRACER_DMG_URL` | Direct DMG URL for Cisco Packet Tracer (SharePoint links supported) |
| `LOCKSCREEN_IMAGE_URL` | Custom wallpaper/lock screen image URL |
| `RELEASES_REPO` | Override GitHub repo used to resolve release assets |
| `BLENDER_DMG_URL` / `BLENDER_VERSION` | Override Blender download URL and version |
