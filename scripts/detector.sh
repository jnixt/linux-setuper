#!/usr/bin/env bash

# --- 1. Distro & Derivation ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$NAME
    
    # Check for ID_LIKE (derivation), excluding Ubuntu
    if [[ -n "$ID_LIKE" && "$ID_LIKE" != "ubuntu" ]]; then
        DERIVATIVE=$ID_LIKE
    fi
fi

# --- 2. Package Manager ---
if command -v pacman >/dev/null; then PM="pacman";
elif command -v apt >/dev/null; then PM="apt";
elif command -v dnf >/dev/null; then PM="dnf";
elif command -v zypper >/dev/null; then PM="zypper";
else PM="unknown"; fi

# --- 3. CPU & GPU ---
CPU=$(lscpu | grep "Model name" | sed 's/Model name: *//' | xargs)
GPU=$(lspci | grep -i 'vga\|3d\|display' | cut -d: -f3 | sed 's/.*\[//;s/\].*//' | head -n 1 | xargs)

# --- 4. Form Factor ---
CHASSIS=$(hostnamectl chassis)

if [[ "$CHASSIS" == "container" ]]; then
    FORM="Container"
elif [[ "$CHASSIS" == "convertible" ]]; then
    FORM="Convertible"
elif [[ "$CHASSIS" == "desktop" ]]; then
    FORM="Desktop"
elif [[ "$CHASSIS" == "embedded" ]]; then
    FORM="Embedded"
elif [[ "$CHASSIS" == "handset" ]]; then
    FORM="Handset"
elif [[ "$CHASSIS" == "laptop" ]]; then
    FORM="Laptop"
elif [[ "$CHASSIS" == "server" ]]; then
    FORM="Server"
elif [[ "$CHASSIS" == "tablet" ]]; then
    FORM="Tablet"
elif [[ "$CHASSIS" == "vm" ]]; then
    FORM="Virtual Machine"
elif [[ "$CHASSIS" == "watch" ]]; then
    FORM="Watch"
else
    FORM="Unknown"
fi

# --- 5. DE or WM ---
# Improved detection: Check for common DE session variables first
if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
    ENV_TYPE="DE"
    ENV_NAME=$XDG_CURRENT_DESKTOP
elif [[ -n "$XDG_SESSION_DESKTOP" ]]; then
    ENV_TYPE="WM"
    ENV_NAME=$XDG_SESSION_DESKTOP
elif [[ -n "$DESKTOP_SESSION" ]]; then
    ENV_TYPE="DE/WM"
    ENV_NAME=$DESKTOP_SESSION
else
    # Check running processes if variables are empty (common in minimal WMs)
    if pgrep -x "Hyprland" >/dev/null; then ENV_TYPE="WM"; ENV_NAME="Hyprland";
    elif pgrep -x "sway" >/dev/null; then ENV_TYPE="WM"; ENV_NAME="Sway";
    elif pgrep -x "i3" >/dev/null; then ENV_TYPE="WM"; ENV_NAME="i3";
    else ENV_TYPE="WM"; ENV_NAME="None/TTY"; fi
fi

# --- FINAL OUTPUT ---
# Using printf for cleaner alignment
printf "%-18s: %s\n" "Distro" "$DISTRO"
[[ -n "$DERIVATIVE" ]] && printf "%-18s: %s\n" "Derivative" "$DERIVATIVE"
printf "%-18s: %s\n" "Package Manager" "$PM"
printf "%-18s: %s\n" "CPU" "$CPU"
printf "%-18s: %s\n" "GPU" "$GPU"
printf "%-18s: %s\n" "Form" "$FORM"
printf "%-18s: %s\n" "$ENV_TYPE" "$ENV_NAME"
