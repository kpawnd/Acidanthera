#!/bin/bash

get_app_version() {
    local app_path="$1"
    local plist="$app_path/Contents/Info.plist"
    local version=""

    if [[ ! -f "$plist" ]]; then
        echo "unknown"
        return 0
    fi

    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
    if [[ -z "$version" ]]; then
        version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)"
    fi
    if [[ -z "$version" ]]; then
        version="unknown"
    fi

    echo "$version"
}

report_installed_app_versions() {
    local py_script="${ACID_ROOT}/scripts/py/report_apps.py"
    local line app_name status version
    local azure_app="/Applications/Azure Data Studio.app"
    local blender_app="/Applications/Blender.app"
    local android_app="/Applications/Android Studio.app"

    print_info "Checking installed app versions..."

    if command -v python3 >/dev/null 2>&1 && [[ -f "$py_script" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            app_name="${line%%|*}"
            status="${line#*|}"
            status="${status%%|*}"
            version="${line##*|}"

            if [[ "$status" == "installed" ]]; then
                print_ok "$app_name installed. Version: $version"
            else
                print_info "$app_name not installed."
            fi
        done < <(python3 "$py_script" 2>/dev/null)
        return 0
    fi

    if [[ -d "$azure_app" ]]; then
        print_ok "Azure Data Studio installed. Version: $(get_app_version "$azure_app")"
    else
        print_info "Azure Data Studio not installed."
    fi

    if [[ -d "$blender_app" ]]; then
        print_ok "Blender installed. Version: $(get_app_version "$blender_app")"
    else
        print_info "Blender not installed."
    fi

    if [[ -d "$android_app" ]]; then
        print_ok "Android Studio installed. Version: $(get_app_version "$android_app")"
    else
        print_info "Android Studio not installed."
    fi

    return 0
}

remove_deepfreeze_and_faronics() {
    local had_error=0
    local label
    local matched=0
    local pattern
    local path

    local -a service_patterns=(
        "faronics"
        "deepfreeze"
        "deep[[:space:]_-]*freeze"
    )

    local -a known_path_patterns=(
        "/Applications/Deep Freeze.app"
        "/Applications/Faronics*.app"
        "/Library/Application Support/Faronics"
        "/Library/Application Support/Deep Freeze"
        "/Library/LaunchDaemons/com.faronics*.plist"
        "/Library/LaunchDaemons/com.deepfreeze*.plist"
        "/Library/LaunchAgents/com.faronics*.plist"
        "/Library/LaunchAgents/com.deepfreeze*.plist"
        "/Library/Preferences/com.faronics*"
        "/Library/Preferences/com.deepfreeze*"
        "/Library/PrivilegedHelperTools/com.faronics*"
        "/Library/PrivilegedHelperTools/com.deepfreeze*"
        "/private/var/db/receipts/*faronics*"
        "/private/var/db/receipts/*deepfreeze*"
        "$HOME/Library/Application Support/Faronics"
        "$HOME/Library/Application Support/Deep Freeze"
        "$HOME/Library/Preferences/com.faronics*"
        "$HOME/Library/Preferences/com.deepfreeze*"
    )

    print_info "Removing Deep Freeze / Faronics from known service labels and known paths."

    while IFS= read -r label; do
        [[ -z "$label" ]] && continue
        for pattern in "${service_patterns[@]}"; do
            if [[ "$label" =~ $pattern ]]; then
                matched=1
                print_info "Stopping launch service: $label"
                if ! sudo launchctl bootout system "$label" >/dev/null 2>&1; then
                    sudo launchctl remove "$label" >/dev/null 2>&1 || {
                        print_warn "Could not fully remove service: $label"
                        had_error=1
                    }
                fi
                break
            fi
        done
    done < <(launchctl list 2>/dev/null | awk '{print $3}')

    shopt -s nullglob
    for pattern in "${known_path_patterns[@]}"; do
        for path in $pattern; do
            [[ -e "$path" ]] || continue
            matched=1
            print_info "Deleting known path: $path"
            sudo launchctl unload "$path" >/dev/null 2>&1 || true
            if ! sudo rm -rf "$path"; then
                print_warn "Could not delete: $path"
                had_error=1
            fi
        done
    done
    shopt -u nullglob

    if [[ "$matched" -eq 0 ]]; then
        print_info "No known Deep Freeze / Faronics service labels or paths found."
    fi

    if [[ "$had_error" -eq 1 ]]; then
        print_warn "Deep Freeze / Faronics known-path cleanup completed with some failures."
        return 1
    fi

    print_ok "Deep Freeze / Faronics known-path cleanup completed."
    return 0
}
