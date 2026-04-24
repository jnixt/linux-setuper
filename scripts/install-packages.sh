#!/usr/bin/env bash

# ==============================================================================
#  install-packages.sh
#  Installs all packages for the linux-setuper dotfile setup.
#
#  - Auto-loads SYS[] from detector.sh if not already sourced
#  - Authenticates sudo exactly once and keeps it alive for the full install
#  - Handles per-distro package name differences
#  - Conditional installs: rofi (WM only), yay (Arch only), wallpaper tools
#  - Special installs: tailscale, zed, yazi/fastfetch fallbacks, torbrowser
#
#  Safe to re-run — already-installed packages are skipped.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 0. Bootstrap
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load SYS[] if not already populated (e.g. when run standalone)
if [[ ! -v SYS ]]; then
    source "$SCRIPT_DIR/detector.sh"
fi

# --- Helpers (consistent with rest of project) --------------------------------
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log()       { printf "  ${CYAN}•${RESET}  %s\n" "$*"; }
ok()        { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
warn()      { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; }
die()       { printf "  ${RED}✖${RESET}  %s\n" "$*" >&2; exit 1; }
section()   { printf "\n${BOLD}  %s${RESET}\n${DIM}%s${RESET}\n" "$*" "────────────────────────────────────────"; }
has()       { command -v "$1" >/dev/null 2>&1; }

# ==============================================================================
# 1. Sudo: authenticate once, keep alive for the entire script
# ==============================================================================

section "Privilege Setup"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
    ok "Running as root — no password needed"
else
    log "Enter your password once. It will be cached for the full install."
    sudo -v || die "Failed to authenticate with sudo."

    # Refresh the sudo timestamp every 50 s so it never expires mid-install
    ( while kill -0 $$ 2>/dev/null; do
        sudo -n true
        sleep 50
    done ) &
    _KA_PID=$!

    # Revoke sudo and kill keepalive when this script exits for any reason
    trap 'kill "$_KA_PID" 2>/dev/null; sudo -k' EXIT

    SUDO="sudo"
    ok "Sudo credentials cached"
fi

# ==============================================================================
# 2. Package manager helpers
# ==============================================================================

PM="${SYS[PM]}"

_update() {
    case "$PM" in
        pacman) $SUDO pacman -Sy --noconfirm ;;
        apt)    $SUDO apt-get update -qq ;;
        dnf)    : ;; # dnf refreshes metadata automatically
        zypper) $SUDO zypper refresh ;;
        *)      die "Unsupported package manager: $PM" ;;
    esac
}

# Install one or more packages; skip if already present (--needed / equivalent)
_install() {
    [[ $# -eq 0 ]] && return 0
    case "$PM" in
        pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
        apt)    $SUDO apt-get install -y "$@" ;;
        dnf)    $SUDO dnf install -y "$@" ;;
        zypper) $SUDO zypper install -y --no-confirm "$@" ;;
    esac
}

# Try to install; warn instead of dying if a package is not found
_try_install() {
    local pkg="$1"
    case "$PM" in
        pacman) $SUDO pacman -S --needed --noconfirm "$pkg" 2>/dev/null && return 0 ;;
        apt)    $SUDO apt-get install -y "$pkg" 2>/dev/null && return 0 ;;
        dnf)    $SUDO dnf install -y "$pkg" 2>/dev/null && return 0 ;;
        zypper) $SUDO zypper install -y --no-confirm "$pkg" 2>/dev/null && return 0 ;;
    esac
    warn "Package not found in repos: $pkg"
    return 1
}

# ==============================================================================
# 3. Build package lists
# ==============================================================================

# --- 3a. Packages with identical names on every distro -----------------------
PKGS_COMMON=(
    zsh
    git
    curl
    wget
    vim
    tmux
    ncdu
    btop
    kitty
    micro
)

# --- 3b. Packages whose names differ per distro ------------------------------
declare -a PKGS_NATIVE=()

case "$PM" in
    pacman)
        PKGS_NATIVE=(
            openssh             # ssh
            firefox             # browser
            7zip                # archive
            fastfetch           # system info
            yazi                # file manager
            torbrowser-launcher # tor browser
        )
        ;;
    apt)
        PKGS_NATIVE=(
            openssh-client      # ssh
            firefox             # browser (firefox-esr on older Debian)
            7zip                # archive; fallback p7zip-full handled below
            fastfetch           # Ubuntu 24.04+; older = GitHub binary fallback
            yazi                # Ubuntu 24.04+; older = cargo fallback
            torbrowser-launcher # tor browser
        )
        ;;
    dnf)
        PKGS_NATIVE=(
            openssh-clients     # ssh
            firefox             # browser
            p7zip               # archive (no native 7zip pkg on rpm)
            p7zip-plugins       # archive extras
            fastfetch           # system info (Fedora 40+)
            yazi                # file manager (Fedora 40+)
            torbrowser-launcher # tor browser
        )
        ;;
    zypper)
        PKGS_NATIVE=(
            openssh             # ssh
            MozillaFirefox      # browser (openSUSE package name)
            7zip                # archive
            fastfetch           # system info
            # yazi        → cargo fallback below (not in openSUSE repos)
            # torbrowser  → flatpak fallback below (not in openSUSE repos)
        )
        ;;
esac

# --- 3c. Rofi (WM setups only — DEs have their own launchers) ----------------
declare -a PKGS_WM=()

if [[ "${SYS[ENV_TYPE]}" == "WM" ]]; then
    case "$PM" in
        # rofi-wayland is AUR-only on Arch; installed via yay later
        # Regular X11 rofi is in the official Arch repos for X11 WMs
        pacman)
            if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
                PKGS_WM+=( rofi )
            fi
            # Wayland: rofi-wayland installed via yay in section 5
            ;;
        *)
            # All other distros ship a rofi build with Wayland support included
            PKGS_WM+=( rofi )
            ;;
    esac
fi

# --- 3d. Wallpaper tools (based on session type) -----------------------------
declare -a PKGS_WALLPAPER=()

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    # Wayland: swaybg as the static-capable daemon available in all repos.
    # swww (animated) + hyprpaper are AUR-only on Arch → installed via yay.
    # On non-Arch distros swww is installed via its binary release below.
    PKGS_WALLPAPER+=( swaybg )
else
    # X11: feh is universal
    PKGS_WALLPAPER+=( feh )
fi

# --- 3e. Final combined list --------------------------------------------------
PKGS_ALL=(
    "${PKGS_COMMON[@]}"
    "${PKGS_NATIVE[@]}"
    "${PKGS_WM[@]}"
    "${PKGS_WALLPAPER[@]}"
)

# ==============================================================================
# 4. Main package install
# ==============================================================================

section "Updating package database"
_update
ok "Package database up to date"

section "Installing packages via $PM"
log "Installing: ${PKGS_ALL[*]}"
_install "${PKGS_ALL[@]}"
ok "Core packages installed"

# ==============================================================================
# 5. Arch-specific: yay + AUR packages
# ==============================================================================

if [[ "$PM" == "pacman" ]]; then

    section "AUR Helper — yay"

    if has yay; then
        ok "yay already installed — skipping"
    elif [[ $EUID -eq 0 ]]; then
        warn "Cannot build yay as root (makepkg blocks it)."
        warn "After setup, run as a normal user:  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    else
        log "Building yay from AUR…"
        _install git base-devel

        _yay_tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/yay.git "$_yay_tmp"
        # makepkg handles its own sudo internally; do NOT prefix with $SUDO
        ( cd "$_yay_tmp" && makepkg -si --noconfirm )
        rm -rf "$_yay_tmp"
        ok "yay installed"
    fi

    # AUR packages (only if yay is now available)
    if has yay; then
        section "AUR packages"

        declare -a AUR_PKGS=( swww hyprpaper )

        # rofi-wayland for Wayland WM setups
        if [[ "${SYS[ENV_TYPE]}" == "WM" && -n "${WAYLAND_DISPLAY:-}" ]]; then
            AUR_PKGS+=( rofi-wayland )
        fi

        log "Installing AUR packages: ${AUR_PKGS[*]}"
        # yay is always run as the current (non-root) user
        yay -S --needed --noconfirm "${AUR_PKGS[@]}"
        ok "AUR packages installed"
    else
        warn "yay not available — AUR packages (swww, hyprpaper, rofi-wayland) were not installed."
        warn "Install them manually once yay is set up."
    fi

fi

# ==============================================================================
# 6. Tailscale — official installer (handles all distros + repo setup)
# ==============================================================================

section "Tailscale"

if has tailscale; then
    ok "Tailscale already installed — skipping"
else
    log "Installing via official script (auto-detects distro and adds repo)…"
    curl -fsSL https://tailscale.com/install.sh | $SUDO sh
    ok "Tailscale installed"
fi

# ==============================================================================
# 7. Zed editor
# ==============================================================================

section "Zed Editor"

if has zed || has zeditor; then
    ok "Zed already installed — skipping"
elif [[ "$PM" == "pacman" ]] && has yay; then
    log "Installing zed-editor via AUR…"
    yay -S --needed --noconfirm zed-editor
    ok "Zed installed via AUR"
else
    log "Installing via official script (installs to ~/.local/bin)…"
    curl -fsSL https://zed.dev/install.sh | sh
    ok "Zed installed"
fi

# ==============================================================================
# 8. Fallbacks for packages that may not be in all distro repos
# ==============================================================================

# --- 8a. yazi (openSUSE or older apt/dnf where it isn't packaged) ------------
section "Yazi (fallback check)"

if has yazi; then
    ok "yazi already installed"
else
    if has cargo; then
        log "yazi not in repos — installing via cargo…"
        cargo install --locked yazi-fm yazi-cli
        ok "yazi installed via cargo"
    else
        # Last resort: grab the latest binary from GitHub releases
        log "yazi not in repos and cargo not found — fetching binary release…"
        _yazi_tmp=$(mktemp -d)
        _yazi_url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
        curl -fsSL "$_yazi_url" -o "$_yazi_tmp/yazi.zip"
        unzip -q "$_yazi_tmp/yazi.zip" -d "$_yazi_tmp"
        $SUDO install -Dm755 "$_yazi_tmp"/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/yazi
        $SUDO install -Dm755 "$_yazi_tmp"/yazi-x86_64-unknown-linux-gnu/ya   /usr/local/bin/ya
        rm -rf "$_yazi_tmp"
        ok "yazi installed from GitHub release"
    fi
fi

# --- 8b. fastfetch (older apt distros that don't package it) -----------------
section "Fastfetch (fallback check)"

if has fastfetch; then
    ok "fastfetch already installed"
elif [[ "$PM" == "apt" ]]; then
    log "fastfetch not in repos — fetching .deb from GitHub releases…"
    _ff_tmp=$(mktemp -d)
    _ff_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb"
    curl -fsSL "$_ff_url" -o "$_ff_tmp/fastfetch.deb"
    $SUDO dpkg -i "$_ff_tmp/fastfetch.deb"
    rm -rf "$_ff_tmp"
    ok "fastfetch installed from GitHub release"
fi

# --- 8c. swww on non-Arch Wayland setups (binary release) --------------------
#     On Arch this was handled by yay above; everywhere else grab the binary.
if [[ -n "${WAYLAND_DISPLAY:-}" && "$PM" != "pacman" ]]; then
    section "swww (Wayland animated wallpaper)"

    if has swww; then
        ok "swww already installed — skipping"
    else
        log "Installing swww from GitHub releases…"
        _swww_tmp=$(mktemp -d)
        _swww_url="https://github.com/LGFae/swww/releases/latest/download/swww-x86_64-unknown-linux-musl.tar.gz"
        curl -fsSL "$_swww_url" -o "$_swww_tmp/swww.tar.gz"
        tar -xzf "$_swww_tmp/swww.tar.gz" -C "$_swww_tmp"
        $SUDO install -Dm755 "$_swww_tmp/swww"        /usr/local/bin/swww
        $SUDO install -Dm755 "$_swww_tmp/swww-daemon" /usr/local/bin/swww-daemon
        rm -rf "$_swww_tmp"
        ok "swww installed from GitHub release"
    fi
fi

# --- 8d. Tor Browser — flatpak fallback for openSUSE -------------------------
if [[ "$PM" == "zypper" ]]; then
    section "Tor Browser (openSUSE)"

    if has torbrowser-launcher; then
        ok "torbrowser-launcher already installed"
    elif has flatpak; then
        log "Installing torbrowser-launcher via Flatpak…"
        flatpak install -y flathub com.github.micahflee.torbrowser-launcher
        ok "Tor Browser installed via Flatpak"
    else
        warn "torbrowser-launcher is not available on openSUSE repos."
        warn "Install flatpak and run:  flatpak install flathub com.github.micahflee.torbrowser-launcher"
    fi
fi

# --- 8e. 7zip fallback for older apt (Ubuntu < 22.04 / older Debian) ---------
if [[ "$PM" == "apt" ]] && ! has 7zz && ! has 7z; then
    section "7zip (older apt fallback)"
    log "7zip not found — trying p7zip-full…"
    _try_install p7zip-full && ok "p7zip-full installed as 7zip fallback"
fi

# ==============================================================================
# 9. Hyprland-specific packages
# ==============================================================================

if [[ "${SYS[ENV_NAME],,}" == *hyprland* ]]; then

    section "Hyprland-specific packages"

    # --- 9a. Packages available on all distros --------------------------------
    PKGS_HYPR_COMMON=( wl-clipboard brightnessctl playerctl gpicview upower )
    log "Installing: ${PKGS_HYPR_COMMON[*]}"
    _install "${PKGS_HYPR_COMMON[@]}"
    ok "Common Hyprland deps installed"

    # --- 9b. cliphist ---------------------------------------------------------
    # In Arch repos; available in newer apt/dnf repos; GitHub binary fallback
    if has cliphist; then
        ok "cliphist already installed"
    elif ! _try_install cliphist; then
        log "cliphist not in repos — fetching binary from GitHub…"
        _ch_tmp=$(mktemp -d)
        _ch_url="https://github.com/sentriz/cliphist/releases/latest/download/v0.5.0-linux-amd64"
        curl -fsSL "$_ch_url" -o "$_ch_tmp/cliphist"
        $SUDO install -Dm755 "$_ch_tmp/cliphist" /usr/local/bin/cliphist
        rm -rf "$_ch_tmp"
        ok "cliphist installed from GitHub release"
    fi

    # --- 9c. hyprshot ----------------------------------------------------------
    # Hyprland-specific (uses hyprctl IPC); AUR on Arch.
    # On other distros, fall back to grim + slurp (the standard Wayland tools).
    if has hyprshot; then
        ok "hyprshot already installed"
    elif [[ "$PM" == "pacman" ]] && has yay; then
        log "Installing hyprshot via AUR…"
        yay -S --needed --noconfirm hyprshot
        ok "hyprshot installed"
    else
        warn "hyprshot is AUR-only and unavailable for $PM."
        warn "Installing grim + slurp as a screenshot alternative…"
        _install grim slurp
        ok "grim + slurp installed (use: grim -g \"\$(slurp)\" screenshot.png)"
    fi

    # --- 9d. missioncenter (task manager) -------------------------------------
    # AUR on Arch; Flatpak everywhere else (btop is always available as a TUI alt)
    if has missioncenter || has io.missioncenter.MissionCenter; then
        ok "Mission Center already installed"
    elif [[ "$PM" == "pacman" ]] && has yay; then
        log "Installing mission-center via AUR…"
        yay -S --needed --noconfirm mission-center
        ok "Mission Center installed"
    elif has flatpak; then
        log "Installing Mission Center via Flatpak…"
        flatpak install -y flathub io.missioncenter.MissionCenter
        ok "Mission Center installed via Flatpak"
    else
        warn "Mission Center not available for $PM without Flatpak — btop is already installed as a TUI alternative."
    fi

fi

# ==============================================================================
# 10. Done
# ==============================================================================

section "Package Installation Complete"
ok "All packages installed successfully."
printf "\n  ${DIM}Next step: run setup-zsh.sh to configure your shell.${RESET}\n\n"
