#!/bin/bash

require_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_err "This script is for macOS only."
        return 1
    fi

    return 0
}

ensure_admin_user() {
    local check_user="${SUDO_USER:-$USER}"

    if ! id -Gn "$check_user" | tr ' ' '\n' | grep -qx "admin"; then
        print_warn "Current user is not in the admin group."
        print_warn "Power settings and service setup may fail without admin privileges."
        return 0
    fi

    print_ok "Admin group membership detected for user: $check_user"
    return 0
}

ensure_sudo_session() {
    if [[ "$EUID" -eq 0 ]]; then
        return 0
    fi

    print_info "Requesting sudo access (needed for system changes)."
    # Authenticate once upfront
    if ! sudo -v; then
        print_error "Failed to acquire sudo access."
        return 1
    fi
    # Update sudoers to allow NOPASSWD for the duration of this session
    # This way background processes don't need to prompt again
    start_sudo_keepalive
}

start_sudo_keepalive() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        return 0
    fi

    (
        while true; do
            # Refresh sudo token every 50 seconds (before it expires at 60s default)
            /usr/bin/sudo -nv >/dev/null 2>&1 || exit 0
            sleep 50
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
    export SUDO_KEEPALIVE_PID
}

stop_sudo_keepalive() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}
