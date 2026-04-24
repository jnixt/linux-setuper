#!/usr/bin/env bash

# ==============================================================================
#  detector.sh
#  Detects system properties and seals them inside a single associative array
#  (SYS) to avoid colliding with any existing environment variables.
#
#  Usage (from another script):
#    source "$SCRIPT_DIR/scripts/detector.sh"
#    echo "${SYS[DISTRO]}"
#    echo "${SYS[PM]}"
# ==============================================================================

declare -A SYS

# --- 1. Distro & Derivative ---
if [ -f /etc/os-release ]; then
    # Source into a subshell and cherry-pick only what we need, so the dozens
    # of variables defined in os-release don't leak into the caller's env.
    _os_name=$(. /etc/os-release && echo "$NAME")
    _os_id_like=$(. /etc/os-release && echo "${ID_LIKE:-}")

    SYS[DISTRO]="$_os_name"

    if [[ -n "$_os_id_like" && "$_os_id_like" != "ubuntu" ]]; then
        SYS[DERIVATIVE]="$_os_id_like"
    else
        SYS[DERIVATIVE]=""
    fi

    unset _os_name _os_id_like
fi

# --- 2. Package Manager ---
if   command -v pacman >/dev/null 2>&1; then SYS[PM]="pacman";
elif command -v apt    >/dev/null 2>&1; then SYS[PM]="apt";
elif command -v dnf    >/dev/null 2>&1; then SYS[PM]="dnf";
elif command -v zypper >/dev/null 2>&1; then SYS[PM]="zypper";
else SYS[PM]="unknown"; fi

# --- 3. CPU & GPU ---
SYS[CPU]=$(lscpu | grep "Model name" | sed 's/Model name:[[:space:]]*//' | xargs)
SYS[GPU]=$(lspci 2>/dev/null \
    | grep -i 'vga\|3d\|display' \
    | cut -d: -f3 \
    | sed 's/.*\[//;s/\].*//' \
    | head -n 1 \
    | xargs)

# --- 4. Form Factor ---
_chassis=$(hostnamectl chassis 2>/dev/null)

case "$_chassis" in
    container)   SYS[FORM]="Container" ;;
    convertible) SYS[FORM]="Convertible" ;;
    desktop)     SYS[FORM]="Desktop" ;;
    embedded)    SYS[FORM]="Embedded" ;;
    handset)     SYS[FORM]="Handset" ;;
    laptop)      SYS[FORM]="Laptop" ;;
    server)      SYS[FORM]="Server" ;;
    tablet)      SYS[FORM]="Tablet" ;;
    vm)          SYS[FORM]="Virtual Machine" ;;
    watch)       SYS[FORM]="Watch" ;;
    *)           SYS[FORM]="Unknown" ;;
esac

unset _chassis

# --- 5. DE or WM ---
# Prefer XDG env vars (set by login managers / DE session).
# Fall back to process scanning for minimal WMs that set nothing.
if   [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
    SYS[ENV_TYPE]="DE"
    SYS[ENV_NAME]="$XDG_CURRENT_DESKTOP"
elif [[ -n "$XDG_SESSION_DESKTOP" ]]; then
    SYS[ENV_TYPE]="WM"
    SYS[ENV_NAME]="$XDG_SESSION_DESKTOP"
elif [[ -n "$DESKTOP_SESSION" ]]; then
    SYS[ENV_TYPE]="DE/WM"
    SYS[ENV_NAME]="$DESKTOP_SESSION"
else
    if   pgrep -x "Hyprland" >/dev/null 2>&1; then SYS[ENV_TYPE]="WM"; SYS[ENV_NAME]="Hyprland";
    elif pgrep -x "sway"     >/dev/null 2>&1; then SYS[ENV_TYPE]="WM"; SYS[ENV_NAME]="Sway";
    elif pgrep -x "i3"       >/dev/null 2>&1; then SYS[ENV_TYPE]="WM"; SYS[ENV_NAME]="i3";
    else                                           SYS[ENV_TYPE]="WM"; SYS[ENV_NAME]="None/TTY"; fi
fi
