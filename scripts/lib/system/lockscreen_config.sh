#!/bin/bash

list_lockscreen_target_users() {
    dscl . -list /Users UniqueID 2>/dev/null | awk '$2 >= 500 && $1 != "root" && $1 != "nobody" {print $1}'
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

configure_lockscreen_background() {
    remove_legacy_lockscreen_daemon

    local failed=0
    while IFS= read -r target_user; do
        [[ -n "$target_user" ]] || continue
        if disable_screensaver_for_user "$target_user"; then
            print_ok "Screen saver disabled for $target_user"
        else
            print_warn "Could not disable screen saver for $target_user"
            failed=1
        fi
    done < <(list_lockscreen_target_users)

    if [[ "$failed" -eq 0 ]]; then
        print_ok "Screen saver disabled for all local users."
    fi
    return "$failed"
}
