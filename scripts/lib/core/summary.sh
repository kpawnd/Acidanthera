#!/bin/bash

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
    echo "5. Screen saver disabled for all local user accounts."
    echo "6. Power schedule with pmset (Mon-Sat)."
    echo "   - Wake/Power on: 07:00"
    echo "   - Shutdown: 21:30"
    echo "7. AC wake enabled; Power Nap, hard disk sleep, WoL, and autopoweroff disabled."
    echo "8. Autorestart after power failure enabled."
    echo "9. System monitor command installed: ~/.local/bin/sysmon"
    echo "10. Bash alias added: sysmon"
    echo "11. Performance tweaks applied (Spotlight/animations/Dock)."
    echo "12. Reinstall target apps: Blender, Android Studio, Azure Data Studio, Cisco Packet Tracer,"
    echo "    Microsoft Office, Microsoft Teams, Adobe Creative Cloud."
    echo ""
    echo "Use now:"
    echo "- sysmon           (live terminal monitor)"
    echo "- sysmon --once    (single snapshot)"
    echo ""
    if [[ "$FIRMWARE_PASSWORD_CHANGED" -eq 1 ]]; then
        print_warn "Firmware password was changed. Restart is recommended before validation."
    fi
    print_info "Open a new shell (or run: source ~/.bashrc) to use the alias immediately."
}
