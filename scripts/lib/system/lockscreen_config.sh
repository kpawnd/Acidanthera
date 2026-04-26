#!/bin/bash

# Best-effort lock screen/login window background customization
# Works across macOS Monterey (12) through Sequoia (15)

apply_wallpaper_for_user() {
    local target_user="$1"
    local image_path="$2"
    local target_uid

    target_uid="$(id -u "$target_user" 2>/dev/null || true)"
    if [[ -z "$target_uid" ]]; then
        return 1
    fi

    # gui/<uid> only exists when the user is actively logged into a GUI session.
    # user/<uid> is kept alive by launchd for all users regardless of login state —
    # using that domain would always take the osascript path and silently fail for
    # any user who is not currently at the login window.
    if launchctl print "gui/$target_uid" >/dev/null 2>&1; then
        launchctl asuser "$target_uid" sudo -u "$target_user" osascript \
            -e 'tell application "System Events"' \
            -e 'tell every desktop to set picture to POSIX file "'"$image_path"'"' \
            -e 'end tell' >/dev/null 2>&1
        return $?
    fi

    # User is not currently logged in.
    # Resolve home directory from the directory service — eval/~ is unreliable as root.
    local user_home
    user_home="$(dscl . -read "/Users/$target_user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
    [[ -z "$user_home" ]] && user_home="/Users/$target_user"
    [[ -d "$user_home" ]] || return 1

    local prefs_dir="${user_home}/Library/Preferences"
    local plist="${prefs_dir}/com.apple.desktop.plist"

    # Ensure the Preferences directory exists and is owned by the target user.
    if [[ ! -d "$prefs_dir" ]]; then
        sudo mkdir -p "$prefs_dir" >/dev/null 2>&1 && \
            sudo chown "${target_user}" "$prefs_dir" >/dev/null 2>&1 || return 1
    fi

    # PlistBuddy handles nested dicts reliably.
    # Delete any existing Background key first (ignore failure if not present),
    # then rebuild the full nested structure.
    sudo -u "$target_user" /usr/libexec/PlistBuddy \
        -c "Delete :Background" "$plist" >/dev/null 2>&1 || true
    sudo -u "$target_user" /usr/libexec/PlistBuddy \
        -c "Add :Background dict" \
        -c "Add :Background:default dict" \
        -c "Add :Background:default:ImageFilePath string ${image_path}" \
        -c "Add :Background:default:Change string Never" \
        "$plist" >/dev/null 2>&1
}

disable_screensaver_for_user() {
    local target_user="$1"
    local target_uid

    target_uid="$(id -u "$target_user" 2>/dev/null || true)"
    if [[ -z "$target_uid" ]]; then
        return 1
    fi

    # idleTime=0 disables the screen saver. Write to both the regular domain and
    # the ByHost domain (host-specific) since the latter takes precedence on macOS.
    # gui/<uid> only exists for actively logged-in GUI sessions; user/<uid> is always
    # present on Ventura regardless of login state and would route all users through
    # the launchctl asuser path, which silently fails for logged-out users.
    if launchctl print "gui/$target_uid" >/dev/null 2>&1; then
        # User has an active GUI session — run defaults in their context.
        launchctl asuser "$target_uid" sudo -u "$target_user" \
            defaults write com.apple.screensaver idleTime 0 >/dev/null 2>&1 || true
        launchctl asuser "$target_uid" sudo -u "$target_user" \
            defaults -currentHost write com.apple.screensaver idleTime 0 >/dev/null 2>&1 || true
    else
        # User not logged in — write directly to their preferences.
        sudo -u "$target_user" \
            defaults write com.apple.screensaver idleTime 0 >/dev/null 2>&1 || true
        sudo -u "$target_user" \
            defaults -currentHost write com.apple.screensaver idleTime 0 >/dev/null 2>&1 || true
    fi
}

apply_lockscreen_cache_for_user() {
    local target_user="$1"
    local image_path="$2"
    local generated_uid
    local cache_dir

    generated_uid="$(dscl . -read "/Users/$target_user" GeneratedUID 2>/dev/null | awk '{print $2}')"
    if [[ -z "$generated_uid" ]]; then
        return 1
    fi

    cache_dir="/Library/Caches/Desktop Pictures/$generated_uid"
    if ! sudo mkdir -p "$cache_dir"; then
        return 1
    fi

    # Write both png/jpg variants used by different macOS builds.
    sudo cp "$image_path" "$cache_dir/lockscreen.png" 2>/dev/null || return 1
    sudo cp "$image_path" "$cache_dir/lockscreen.jpg" 2>/dev/null || true
    sudo cp "$image_path" "/Library/Caches/com.apple.desktop.admin.png" 2>/dev/null || true
    sudo chmod 644 "$cache_dir/lockscreen.png" "$cache_dir/lockscreen.jpg" "/Library/Caches/com.apple.desktop.admin.png" >/dev/null 2>&1 || true
    sudo chown root:wheel "$cache_dir/lockscreen.png" "$cache_dir/lockscreen.jpg" "/Library/Caches/com.apple.desktop.admin.png" >/dev/null 2>&1 || true

    return 0
}

remove_legacy_lockscreen_daemon() {
    # The com.atherion.lockscreen LaunchDaemon was a dead end:
    #   - RunAtLoad fires AFTER loginwindow has already rendered the boot screen
    #   - The plist keys it wrote (com.apple.loginwindow DesktopPicture /
    #     LockScreenImage) are pre-Big-Sur-era and not honored at cold boot on
    #     Sequoia. /private/var/db/loginwindow paths are no longer authoritative.
    # Tear it down on any machine that still has it installed.
    local daemon_label="com.atherion.lockscreen"
    local daemon_plist="/Library/LaunchDaemons/${daemon_label}.plist"
    local restore_script="/Library/Application Support/Atherion/apply-lockscreen.sh"
    local boot_log="/var/log/atherion-lockscreen-boot.log"

    if [[ -f "$daemon_plist" ]]; then
        sudo launchctl bootout "system/${daemon_label}" >/dev/null 2>&1 || true
        sudo rm -f "$daemon_plist" >/dev/null 2>&1 || true
    fi
    [[ -f "$restore_script" ]] && sudo rm -f "$restore_script" >/dev/null 2>&1 || true
    [[ -f "$boot_log" ]] && sudo rm -f "$boot_log" >/dev/null 2>&1 || true
    return 0
}

# Resolve the path to the macOS default wallpaper that loginwindow loads at
# cold boot. The filename tracks the marketing name of each release.
_resolve_system_wallpaper_path() {
    local v
    v="$(/usr/bin/sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
    case "$v" in
        15) echo "/System/Library/Desktop Pictures/macOS Sequoia.heic" ;;
        14) echo "/System/Library/Desktop Pictures/macOS Sonoma.heic" ;;
        13) echo "/System/Library/Desktop Pictures/macOS Ventura.heic" ;;
        12) echo "/System/Library/Desktop Pictures/Monterey.heic" ;;
        *)  return 1 ;;
    esac
}

# Eligible only when SIP and authenticated-root are BOTH disabled — i.e. an
# OCLP-patched system. Stock macOS keeps /System sealed and read-only; nothing
# we do here can touch it.
_system_wallpaper_replacement_eligible() {
    local sip auth
    sip="$(csrutil status 2>/dev/null)"
    auth="$(csrutil authenticated-root status 2>/dev/null)"
    echo "$sip"  | grep -qi "disabled" || return 1
    echo "$auth" | grep -qi "disabled" || return 1
    return 0
}

# Replace /System/Library/Desktop Pictures/<release>.heic with our image.
# This is the only mechanism that actually changes the cold-boot login screen
# on Sequoia without MDM enrollment. Loginwindow reads this file directly at
# boot — there is no race with launchd because we change the file, not a pref.
replace_system_login_wallpaper() {
    local image_path="$1"
    local target backup heic_temp

    if ! _system_wallpaper_replacement_eligible; then
        print_info "System wallpaper replacement skipped (SIP / authenticated-root not both disabled)"
        return 1
    fi

    target="$(_resolve_system_wallpaper_path 2>/dev/null)"
    if [[ -z "$target" ]]; then
        print_warn "Unsupported macOS version for system wallpaper replacement"
        return 1
    fi
    if [[ ! -f "$target" ]]; then
        print_warn "macOS system wallpaper not found at: $target"
        return 1
    fi

    # The system volume is unsealed on OCLP but may still be mounted read-only.
    # Try a no-op write first; if it fails, remount / read-write.
    if ! sudo test -w "$target" 2>/dev/null; then
        print_info "Remounting / read-write for system wallpaper replacement..."
        sudo mount -uw / >/dev/null 2>&1 || true
    fi

    # Convert source to HEIC so the replacement matches the format loginwindow expects.
    heic_temp="/tmp/atherion-system-wallpaper.heic"
    if ! sips -s format heic "$image_path" --out "$heic_temp" >/dev/null 2>&1; then
        print_warn "Could not convert $image_path to HEIC — sips failed"
        return 1
    fi

    # One-time backup of the pristine file (do not overwrite an existing backup).
    backup="${target}.atherion-original"
    if [[ ! -f "$backup" ]]; then
        sudo cp "$target" "$backup" >/dev/null 2>&1 || true
    fi

    if ! sudo cp "$heic_temp" "$target" >/dev/null 2>&1; then
        print_warn "Could not write $target — system volume is read-only"
        rm -f "$heic_temp" >/dev/null 2>&1 || true
        return 1
    fi
    sudo chmod 644 "$target" >/dev/null 2>&1 || true
    rm -f "$heic_temp" >/dev/null 2>&1 || true

    print_ok "Replaced macOS system wallpaper: $target"
    print_info "Original backed up to: $backup"
    print_info "Note: re-running OCLP root patches restores the stock system volume — re-run this step after every OCLP patch."
    return 0
}


list_lockscreen_target_users() {
    dscl . -list /Users UniqueID 2>/dev/null | awk '$2 >= 500 && $1 != "root" && $1 != "nobody" {print $1}'
}

verify_lockscreen_for_user() {
    local target_user="$1"
    local generated_uid
    local cache_dir
    local png_file

    generated_uid="$(dscl . -read "/Users/$target_user" GeneratedUID 2>/dev/null | awk '{print $2}')"
    [[ -n "$generated_uid" ]] || return 1

    cache_dir="/Library/Caches/Desktop Pictures/$generated_uid"
    png_file="$cache_dir/lockscreen.png"
    [[ -f "$png_file" ]] || return 1
    [[ -s "$png_file" ]] || return 1

    return 0
}

configure_lockscreen_background() {
    # Three distinct macOS "lock-related" screens, what controls each, and what
    # this function actually does about it:
    #
    #   1. Cold-boot login screen (FileVault unlock + first login window)
    #      Pre-Big-Sur this honored com.apple.loginwindow DesktopPicture; on
    #      Big Sur and later the boot screen is dynamic and ignores all
    #      preference files. The ONLY non-MDM mechanism that changes it is
    #      direct replacement of /System/Library/Desktop Pictures/<release>.heic.
    #      Stock macOS keeps /System sealed, but OCLP-patched machines have
    #      authenticated-root disabled and the system volume unsealed — there
    #      we can write the file directly. Handled by replace_system_login_wallpaper.
    #
    #   2. Login window after a previous user has logged in (logout, switch user)
    #      macOS shows the previously-active user's wallpaper here. Setting each
    #      local user's wallpaper covers this case. Handled by apply_wallpaper_for_user.
    #
    #   3. Per-user lock screen (cmd-ctrl-Q, idle lock)
    #      Reads from /Library/Caches/Desktop Pictures/<GUID>/lockscreen.png.
    #      Handled by apply_lockscreen_cache_for_user.
    #
    # Anything else (DesktopPicture/LockScreenImage in com.apple.loginwindow,
    # /private/var/db/loginwindow/..., RunAtLoad daemons that restore those
    # plists) is dead weight on Sequoia and has been removed.

    local image_url="${LOCKSCREEN_IMAGE_URL:-https://wall.tasw.qzz.io/mac.png}"
    local image_file="/tmp/lockscreen_bg.png"
    local persistent_dir="/Library/Application Support/Atherion"
    local persistent_image="$persistent_dir/lockscreen_bg.png"
    local diag_log="/tmp/atherion-lockscreen.log"
    local total_checks=0
    local failed_checks=0

    : > "$diag_log"
    print_info "Diagnostics log: $diag_log"

    # Tear down the legacy boot daemon if a prior version of this script installed it.
    remove_legacy_lockscreen_daemon

    print_info "Downloading lockscreen image..."
    if ! curl -fsSL --connect-timeout 10 --max-time 60 "$image_url" -o "$image_file"; then
        print_warn "Failed to download lockscreen image from $image_url"
        return 1
    fi
    total_checks=$((total_checks + 1))
    print_ok "Check $total_checks: image download"

    if ! file "$image_file" | grep -q "image"; then
        print_warn "Downloaded file is not a valid image"
        rm -f "$image_file"
        return 1
    fi
    total_checks=$((total_checks + 1))
    print_ok "Check $total_checks: image validation"

    if ! sudo mkdir -p "$persistent_dir"; then
        print_warn "Failed to create lockscreen directory: $persistent_dir"
        rm -f "$image_file"
        return 1
    fi
    if ! sudo cp "$image_file" "$persistent_image"; then
        print_warn "Failed to copy lockscreen image to $persistent_image"
        rm -f "$image_file"
        return 1
    fi
    sudo chmod 644 "$persistent_image" >/dev/null 2>&1 || true
    total_checks=$((total_checks + 1))
    print_ok "Check $total_checks: persistent image write"
    echo "PersistentImage=$persistent_image" >> "$diag_log" 2>/dev/null || true

    # ── Cold-boot login screen (#1) ────────────────────────────────────────────
    # Only works on OCLP-style systems where SIP and authenticated-root are both
    # disabled. Default ON if eligible; opt out via LOCKSCREEN_REPLACE_SYSTEM=0.
    local replace_system="${LOCKSCREEN_REPLACE_SYSTEM:-1}"
    if [[ "$replace_system" == "1" ]]; then
        print_info "Attempting cold-boot wallpaper replacement (system .heic)..."
        if replace_system_login_wallpaper "$persistent_image"; then
            total_checks=$((total_checks + 1))
            print_ok "Check $total_checks: system login wallpaper replaced"
            echo "SystemWallpaperReplaced=yes" >> "$diag_log" 2>/dev/null || true
        else
            print_info "Cold-boot wallpaper unchanged — see message above for reason."
            echo "SystemWallpaperReplaced=no" >> "$diag_log" 2>/dev/null || true
        fi
    else
        print_info "Cold-boot wallpaper replacement disabled (LOCKSCREEN_REPLACE_SYSTEM=0)"
    fi

    # ── Per-user lock screen (#3) and post-login wallpaper (#2) ────────────────
    print_info "Applying per-user lock screen cache and desktop wallpaper..."

    local set_wallpaper="${LOCKSCREEN_SET_WALLPAPER:-1}"
    local applied_any=0
    while IFS= read -r target_user; do
        [[ -n "$target_user" ]] || continue

        if apply_lockscreen_cache_for_user "$target_user" "$persistent_image"; then
            if verify_lockscreen_for_user "$target_user"; then
                total_checks=$((total_checks + 1))
                print_ok "Check $total_checks: lock screen cache ($target_user)"
            else
                print_warn "Lock screen cache verify failed for $target_user"
                failed_checks=$((failed_checks + 1))
            fi
            applied_any=1
        else
            print_warn "Could not update lock screen cache for $target_user"
            failed_checks=$((failed_checks + 1))
        fi

        if [[ "$set_wallpaper" == "1" ]]; then
            if apply_wallpaper_for_user "$target_user" "$persistent_image"; then
                total_checks=$((total_checks + 1))
                print_ok "Check $total_checks: desktop wallpaper ($target_user)"
                echo "Wallpaper=$target_user OK" >> "$diag_log" 2>/dev/null || true
            else
                print_warn "Could not update wallpaper for $target_user"
                echo "Wallpaper=$target_user FAILED" >> "$diag_log" 2>/dev/null || true
                failed_checks=$((failed_checks + 1))
            fi
        fi

        disable_screensaver_for_user "$target_user" >/dev/null 2>&1 \
            && print_ok "Screen saver disabled for $target_user" \
            || print_warn "Could not disable screen saver for $target_user"
    done < <(list_lockscreen_target_users)

    if [[ "$applied_any" -eq 0 ]]; then
        print_warn "No eligible local users found for lock screen cache update."
        failed_checks=$((failed_checks + 1))
    fi

    rm -f "$image_file"
    print_info "Diagnostics persisted at: $diag_log"
    print_info "Verification summary: passed=${total_checks} failed=${failed_checks}"

    if [[ "$failed_checks" -gt 0 ]]; then
        print_warn "Lock screen / wallpaper configuration is partial. Review warnings above."
        return 1
    fi

    print_ok "Lock screen / wallpaper configured"
    return 0
}

# MDM profile approach for loginwindow policy (no image payload key)
create_lockscreen_mdm_profile() {
    local image_url="${LOCKSCREEN_IMAGE_URL:-https://wall.tasw.qzz.io/mac.png}"
    local profile_id="com.lab.lockscreen.background"
    local profile_file="/tmp/${profile_id}.mobileconfig"
    local profile_uuid="A7B2C3D4-E5F6-47G8-H9I0-J1K2L3M4N5O6"
    
    print_info "Creating loginwindow policy MDM profile for Monterey-Sequoia..."
    
    # Create MDM profile that sets login window properties
    cat > "$profile_file" <<'MDMEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.ManagedClient.preferences</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.lab.lockscreen.background.payload</string>
            <key>PayloadUUID</key>
            <string>PAYLOAD_UUID_HERE</string>
            <key>PayloadDisplayName</key>
            <string>Login Window Policy</string>
            <key>PayloadEnabled</key>
            <true/>
            <key>PayloadOrganization</key>
            <string>Lab</string>
            
            <key>com.apple.loginwindow</key>
            <dict>
                <key>Forced</key>
                <array>
                    <dict>
                        <key>mcx_preference_settings</key>
                        <dict>
                            <key>LoginwindowText</key>
                            <string>Lab System</string>
                            <key>SHOWFULLNAME</key>
                            <false/>
                            <key>DisableConsoleAccess</key>
                            <false/>
                        </dict>
                    </dict>
                </array>
            </dict>
        </dict>
    </array>
    
    <key>PayloadDisplayName</key>
    <string>Lab Login Window Configuration</string>
    <key>PayloadIdentifier</key>
    <string>com.lab.lockscreen.background</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadScope</key>
    <string>System</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>PROFILE_UUID_HERE</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
MDMEOF

    print_info "MDM profile created at $profile_file"
    print_info "To enroll: sudo profiles install -type configuration -path $profile_file"
    print_ok "Loginwindow policy MDM profile ready"
    return 0
}
