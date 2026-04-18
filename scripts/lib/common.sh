#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_STEPS=0
FAILED_STEPS=0
FIRMWARE_PASSWORD_CHANGED=0

print_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_info_inline() {
    if [[ -t 1 ]]; then
        printf "\r\033[2K${BLUE}[INFO]${NC} %s" "$1"
    else
        print_info "$1"
    fi
}

clear_inline_status() {
    if [[ -t 1 ]]; then
        printf "\r\033[2K"
    fi
}

run_step() {
    local step_name="$1"
    shift

    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    print_info "$step_name"

    if "$@"; then
        print_ok "$step_name completed"
    else
        FAILED_STEPS=$((FAILED_STEPS + 1))
        print_warn "$step_name failed, continuing"
    fi
}
