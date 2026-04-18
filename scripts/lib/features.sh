#!/bin/bash

configure_firmware_password() {
    local answer

    if [[ "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)" != *"Intel"* ]]; then
        print_warn "Firmware password tool is not supported on this Mac type. Skipping."
        return 0
    fi

    if [[ ! -x /usr/sbin/firmwarepasswd ]]; then
        print_warn "firmwarepasswd tool not found. Skipping firmware password step."
        return 0
    fi

    read -r -p "Change firmware password now? (y/N): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        print_info "Firmware password change skipped by user."
        return 0
    fi

    print_info "Current firmware password status:"
    sudo /usr/sbin/firmwarepasswd -check || print_warn "Could not read current firmware password status."

    print_info "You will now be prompted for password input by firmwarepasswd."
    print_info "If a firmware password already exists, provide current password first."

    if ! sudo /usr/sbin/firmwarepasswd -setpasswd; then
        print_warn "Firmware password change did not complete."
        return 1
    fi

    FIRMWARE_PASSWORD_CHANGED=1
    print_ok "Firmware password change completed."
    return 0
}

configure_power_management() {
    local had_error=0

    print_info "Applying power management settings..."

    if ! sudo pmset repeat cancel; then
        print_warn "Failed to clear existing pmset repeat schedule."
        had_error=1
    fi

    if ! sudo pmset repeat wakeorpoweron MTWRFS 07:00:00; then
        print_warn "Failed to set wake/power on schedule."
        had_error=1
    fi

    if ! sudo pmset repeat shutdown MTWRFS 21:30:00; then
        print_warn "Failed to set shutdown schedule."
        had_error=1
    fi

    if ! sudo pmset -a acwake 1; then
        print_warn "Failed to enable AC wake."
        had_error=1
    fi

    if ! sudo pmset -a powernap 0; then
        print_warn "Failed to disable Power Nap."
        had_error=1
    fi

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    print_ok "Power schedule set for Mon-Sat: on at 07:00, off at 21:30."
    print_ok "AC wake enabled and Power Nap disabled."
    return 0
}

configure_performance_tweaks() {
    local had_error=0

    print_info "Applying performance tweaks..."

    if ! sudo mdutil -a -i off >/dev/null 2>&1; then
        print_warn "Failed to disable Spotlight indexing."
        had_error=1
    fi

    if ! defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false; then
        print_warn "Failed to disable automatic window animations."
        had_error=1
    fi
    if ! defaults write NSGlobalDomain NSWindowResizeTime -float 0.001; then
        print_warn "Failed to reduce window resize animation time."
        had_error=1
    fi
    if ! defaults write com.apple.dock launchanim -bool false; then
        print_warn "Failed to disable Dock launch animation."
        had_error=1
    fi

    defaults write com.apple.dashboard mcx-disabled -boolean YES >/dev/null 2>&1 || true

    if ! defaults write com.apple.dock expose-animation-duration -float 0; then
        print_warn "Failed to set expose animation duration."
        had_error=1
    fi
    defaults write com.apple.dock springboard-show-duration -int 0 >/dev/null 2>&1 || true
    defaults write com.apple.dock springboard-hide-duration -int 0 >/dev/null 2>&1 || true

    if ! killall Dock >/dev/null 2>&1; then
        print_warn "Could not restart Dock automatically."
        had_error=1
    fi

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    print_ok "Performance tweaks applied."
    return 0
}

create_sysmon_command() {
    local target_dir="$HOME/.local/bin"
    local target_file="$target_dir/sysmon"

    mkdir -p "$target_dir" || return 1

    cat > "$target_file" <<'EOF'
#!/bin/bash
set -uo pipefail

mode="terminal"
if [[ "${1:-}" == "--window" ]]; then
    mode="window"
fi

report_file="/tmp/sysmon_report_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "System Monitor Report - $(date)"
    echo "========================================"
    echo ""

    echo "Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
    echo "Uptime: $(uptime | sed 's/^ *//')"
    echo ""

    echo "CPU"
    echo "----------------------------------------"
    sysctl -n machdep.cpu.brand_string 2>/dev/null || true
    top -l 1 | grep -E '^CPU usage:' || true
    if command -v osx-cpu-temp >/dev/null 2>&1; then
        echo "CPU Temp: $(osx-cpu-temp 2>/dev/null || echo unavailable)"
    elif command -v istats >/dev/null 2>&1; then
        echo "CPU Temp:"
        istats cpu temp --no-graphs 2>/dev/null || echo "unavailable"
    elif command -v powermetrics >/dev/null 2>&1; then
        echo "CPU Temp (powermetrics):"
        sudo -n powermetrics --samplers smc -n 1 2>/dev/null | grep -i 'CPU die temperature' || echo "unavailable (requires sudo permission)"
    else
        echo "CPU Temp: unavailable (install osx-cpu-temp or iStats)"
    fi
    echo ""

    echo "Memory"
    echo "----------------------------------------"
    vm_stat | head -n 8 || true
    echo ""

    echo "Disk"
    echo "----------------------------------------"
    df -h / || true
    echo ""

    echo "Battery"
    echo "----------------------------------------"
    pmset -g batt || true
    echo ""

    echo "Network"
    echo "----------------------------------------"
    networksetup -listallhardwareports 2>/dev/null | grep -E 'Hardware Port|Device:' || true
} > "$report_file"

if [[ "$mode" == "window" ]]; then
    open -a TextEdit "$report_file"
else
    cat "$report_file"
fi
EOF

    chmod +x "$target_file" || return 1
    print_ok "System monitor command created: $target_file"
    return 0
}

ensure_bash_alias() {
    local bashrc="$HOME/.bashrc"
    local bash_profile="$HOME/.bash_profile"
    local alias_line='alias sysmon="$HOME/.local/bin/sysmon"'

    touch "$bashrc" "$bash_profile" || return 1

    if ! grep -Fxq "$alias_line" "$bashrc"; then
        echo "$alias_line" >> "$bashrc" || return 1
        print_ok "Added sysmon alias to $bashrc"
    else
        print_ok "sysmon alias already exists in $bashrc"
    fi

    if ! grep -Fxq "$alias_line" "$bash_profile"; then
        echo "$alias_line" >> "$bash_profile" || return 1
        print_ok "Added sysmon alias to $bash_profile"
    else
        print_ok "sysmon alias already exists in $bash_profile"
    fi

    return 0
}

install_and_configure_skhd() {
    local had_error=0
    local skhd_formula="koekeishiya/formulae/skhd"

    print_info "Installing and configuring skhd for hotkey trigger..."

    if ! ensure_git_installed; then
        print_warn "git is unavailable; skipping skhd setup."
        return 1
    fi

    repair_homebrew_environment || true

    if ! brew_is_healthy; then
        print_warn "Homebrew is unavailable or unhealthy; skipping skhd setup."
        return 1
    fi

    if ! brew list --formula skhd >/dev/null 2>&1; then
        print_info "Adding tap for skhd formula..."
        if ! brew tap koekeishiya/formulae >/dev/null 2>&1; then
            print_warn "Failed to add koekeishiya/formulae tap."
        fi

        print_info "Installing skhd from tap..."
        if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install "$skhd_formula"; then
            print_warn "Primary skhd install failed. Trying HEAD build."
            repair_homebrew_environment || true
            if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install --HEAD "$skhd_formula"; then
                print_warn "Failed to install skhd from koekeishiya/formulae."
                print_warn "Homebrew cannot find the formula in current repositories."
                return 1
            fi
        fi
    fi

    local skhd_bin
    skhd_bin="$(brew --prefix)/bin/skhd"

    if ! cat > "$HOME/.skhdrc" <<'EOF'
# Launch system monitor in Terminal with Option+Command+Shift+S
alt + cmd + shift - s : /usr/bin/osascript -e 'tell application "Terminal" to activate' -e 'tell application "Terminal" to do script "sysmon"'
EOF
    then
        print_warn "Could not write ~/.skhdrc"
        had_error=1
    fi

    local plist_dir="$HOME/Library/LaunchAgents"
    local plist_file="$plist_dir/com.acidanthera.sysmon.skhd.plist"

    mkdir -p "$plist_dir" || {
        print_warn "Could not create LaunchAgents directory."
        return 1
    }

    if ! cat > "$plist_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.acidanthera.sysmon.skhd</string>
    <key>ProgramArguments</key>
    <array>
        <string>$skhd_bin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/skhd.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/skhd.error.log</string>
</dict>
</plist>
EOF
    then
        print_warn "Could not write skhd LaunchAgent plist."
        return 1
    fi

    launchctl unload "$plist_file" >/dev/null 2>&1 || true
    if ! launchctl load "$plist_file"; then
        print_warn "Could not load skhd LaunchAgent."
        had_error=1
    fi

    print_ok "skhd hotkey service configured."
    print_warn "Grant Accessibility permission to skhd in System Settings > Privacy & Security > Accessibility."
    print_ok "Hotkey set: Option + Command + Shift + S"

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    return 0
}

print_summary() {
    echo ""
    echo "Execution summary:"
    echo "- Total steps: $TOTAL_STEPS"
    echo "- Failed steps: $FAILED_STEPS"

    if [[ "$FAILED_STEPS" -eq 0 ]]; then
        print_ok "All steps completed successfully."
    else
        print_warn "Script completed with some failures. Review warnings above."
    fi

    echo ""
    echo "What is configured:"
    echo "1. Homebrew installation attempt."
    echo "2. App version report for Azure Data Studio, Blender, and Android Studio."
    echo "3. Firmware password change routine (interactive user input)."
    echo "4. Known-path Deep Freeze / Faronics cleanup attempt."
    echo "5. Power schedule with pmset (Mon-Sat)."
    echo "   - Wake/Power on: 07:00"
    echo "   - Shutdown: 21:30"
    echo "6. AC wake enabled and Power Nap disabled."
    echo "7. System monitor command installed: ~/.local/bin/sysmon"
    echo "8. Bash alias added: sysmon"
    echo "9. skhd service setup for Option + Command + Shift + S"
    echo "10. Performance tweaks applied (Spotlight/animations/Dock)."
    echo ""
    echo "Use now:"
    echo "- sysmon           (terminal output)"
    echo "- sysmon --window  (opens report in TextEdit)"
    echo ""
    if [[ "$FIRMWARE_PASSWORD_CHANGED" -eq 1 ]]; then
        print_warn "Firmware password was changed. Restart is recommended before validation."
    fi
    print_info "Open a new shell (or run: source ~/.bashrc) to use the alias immediately."
}
