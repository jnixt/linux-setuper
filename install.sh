#!/usr/bin/env bash

# ==============================================================================
#  linux-setuper — install.sh
#  Entry point. Run directly from a cloned repo, or install in one line:
#
#    bash -c "$(curl  -fsSL https://raw.githubusercontent.com/jnixt/linux-setuper/main/install.sh)"
#    bash -c "$(wget  -qO-  https://raw.githubusercontent.com/jnixt/linux-setuper/main/install.sh)"
#
#  Why bash -c "$(...)" and not curl | bash?
#  $() fetches the script first, then bash runs it — stdin stays as your
#  terminal the whole time, so interactive prompts work. curl | bash pipes
#  curl into stdin, which breaks any read command.
#
#  Must be bash (not sh) — this script uses bash-specific features.
# ==============================================================================

set -euo pipefail

# ==============================================================================
# 0. Self-bootstrap
#    When invoked via curl/wget the rest of the repo won't be next to this
#    script. Detect that, download the repo, then re-exec from inside it.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/scripts/detector.sh" ]]; then

    _b_has() { command -v "$1" >/dev/null 2>&1; }
    _b_die() { printf "\033[31m✖\033[0m  %s\n" "$*" >&2; exit 1; }

    printf "\n\033[1m\033[36m  linux-setuper\033[0m — bootstrapping\n"
    printf "\033[2m%s\033[0m\n" "────────────────────────────────────────"

    _REPO="https://github.com/jnixt/linux-setuper"
    _TMPDIR="$(mktemp -d)"

    if _b_has git; then
        printf "  Cloning repo via git…\n"
        git clone --depth 1 "${_REPO}.git" "$_TMPDIR"
    elif _b_has curl; then
        printf "  Downloading archive via curl…\n"
        curl -fsSL "${_REPO}/archive/refs/heads/main.tar.gz" \
            | tar -xz -C "$_TMPDIR" --strip-components=1
    elif _b_has wget; then
        printf "  Downloading archive via wget…\n"
        wget -qO- "${_REPO}/archive/refs/heads/main.tar.gz" \
            | tar -xz -C "$_TMPDIR" --strip-components=1
    else
        _b_die "git, curl, or wget is required to bootstrap. Install one first."
    fi

    # Export so the re-execed script knows to clean this directory up on exit
    export _LINUXSETUPER_TMPDIR="$_TMPDIR"
    exec bash "$_TMPDIR/install.sh"
fi

# ==============================================================================
# 1. Helpers
# ==============================================================================

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
info()      { printf "  ${CYAN}${BOLD}%-18s${RESET}: %s\n" "$1" "$2"; }
section()   { printf "\n${BOLD}  %s${RESET}\n${DIM}%s${RESET}\n" "$1" "────────────────────────────────────────"; }
separator() { printf "${DIM}%s${RESET}\n" "────────────────────────────────────────"; }
has()       { command -v "$1" >/dev/null 2>&1; }

# ==============================================================================
# 2. Cleanup trap — runs on any exit (normal, error, or signal)
# ==============================================================================

_cleanup() {
    # Remove temp clone dir if we were bootstrapped from curl/wget
    if [[ -n "${_LINUXSETUPER_TMPDIR:-}" && -d "${_LINUXSETUPER_TMPDIR:-}" ]]; then
        rm -rf "${_LINUXSETUPER_TMPDIR}" 2>/dev/null || true
        printf "  ${DIM}Cleaned up bootstrap temp dir.${RESET}\n"
    fi
    # Wipe our associative array and exported vars
    unset SYS _LINUXSETUPER_TMPDIR 2>/dev/null || true
}

trap _cleanup EXIT

# ==============================================================================
# 3. System detection + banner
# ==============================================================================

source "$SCRIPT_DIR/scripts/detector.sh"

clear
printf "\n${BOLD}${CYAN}  linux-setuper${RESET}\n"
separator

section "System Information"
info "Distro"           "${SYS[DISTRO]}"
[[ -n "${SYS[DERIVATIVE]:-}" ]] && info "Derivative"       "${SYS[DERIVATIVE]}"
info "Package Manager"  "${SYS[PM]}"
info "CPU"              "${SYS[CPU]}"
info "GPU"              "${SYS[GPU]}"
info "Form"             "${SYS[FORM]}"
info "${SYS[ENV_TYPE]}" "${SYS[ENV_NAME]}"
separator

# ==============================================================================
# 4. Pre-flight checks
# ==============================================================================

section "Pre-flight Checks"

[[ $EUID -ne 0 ]] \
    || die "Do not run as root. The script will invoke sudo when needed."
ok "Running as: $USER"

[[ "${SYS[PM]}" != "unknown" ]] \
    || die "No supported package manager found (pacman / apt / dnf / zypper)."
ok "Package manager: ${SYS[PM]}"

[[ -d "$SCRIPT_DIR/configs" ]] \
    && ok "configs/ present" \
    || warn "configs/ not found — dotfile deployment will be skipped"

separator

# ==============================================================================
# 5. Install packages
#    install-packages.sh manages its own sudo authentication.
# ==============================================================================

section "Package Installation"
bash "$SCRIPT_DIR/scripts/install-packages.sh"

# ==============================================================================
# 6. Deploy dotfiles
# ==============================================================================

section "Deploying Dotfiles"

# _deploy <label> <src-dir> <dst-dir>
#   Copies the *contents* of <src-dir> into <dst-dir>.
#   Creates a timestamped .bak of any pre-existing non-empty <dst-dir>.
_deploy() {
    local label="$1" src="$2" dst="$3"

    if [[ ! -d "$src" ]]; then
        warn "$label — source not found, skipping  ($src)"
        return 0
    fi

    mkdir -p "$dst"

    # Back up a non-empty destination before overwriting
    if [[ -d "$dst" && -n "$(ls -A "$dst" 2>/dev/null)" ]]; then
        local bak="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        cp -r "$dst" "$bak"
        log "Backed up $(basename "$dst")  →  $bak"
    fi

    if has rsync; then
        rsync -a "$src/" "$dst/"
    else
        cp -r "$src/." "$dst/"
    fi

    ok "$label  →  $dst"
}

# ── configs/<name>/ → ~/.config/<name>/ ──────────────────────────────────────
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    for _cfg in "$SCRIPT_DIR/configs"/*/; do
        _cfg_name="$(basename "$_cfg")"
        _deploy "$_cfg_name" "$_cfg" "$HOME/.config/$_cfg_name"
    done
fi

# ── cursors/ → ~/.icons/ ─────────────────────────────────────────────────────
_deploy "cursors" "$SCRIPT_DIR/cursors" "$HOME/.icons"

# ── distro-specific/hypr/ → ~/.config/hypr/ (Hyprland only) ─────────────────
if [[ "${SYS[ENV_NAME],,}" == *hyprland* ]]; then
    _deploy "hyprland config" \
        "$SCRIPT_DIR/distro-specific/hypr" \
        "$HOME/.config/hypr"
fi

# ── Fastfetch helpers: make executable and expose in PATH ─────────────────────
mkdir -p "$HOME/.local/bin"
for _exe in count-packages get-splash; do
    _exe_src="$HOME/.config/fastfetch/$_exe"
    if [[ -f "$_exe_src" ]]; then
        chmod +x "$_exe_src"
        ln -sf "$_exe_src" "$HOME/.local/bin/$_exe"
        ok "$_exe  →  ~/.local/bin/$_exe"
    fi
done

# ── Ensure ~/.local/bin is in PATH (write to shell rc if missing) ─────────────
for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$_rc" ]] && ! grep -q '\.local/bin' "$_rc"; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$_rc"
        ok "Added ~/.local/bin to PATH  ($(basename "$_rc"))"
    fi
done

separator

# ==============================================================================
# 7. Optional setup steps — interactive TUI menu
# ==============================================================================

section "Optional Setup Steps"

printf "\n"
printf "  Select which steps to run.\n"
printf "  Enter numbers separated by spaces, or press ${BOLD}ENTER${RESET} to skip all.\n"
printf "\n"
printf "  ${BOLD}1)${RESET}  show-info      Display detected system information\n"
printf "  ${BOLD}2)${RESET}  set-wallpaper  Apply wallpaper for the current environment\n"
printf "  ${BOLD}3)${RESET}  nerd-fonts     Install Nerd Fonts ${DIM}(pre-selected: JetBrainsMono)${RESET}\n"
printf "  ${BOLD}4)${RESET}  setup-zsh      Configure Zsh + Oh My Zsh + plugins\n"
printf "\n"
printf "${CYAN}  ❯${RESET}  "

read -r _raw_input || _raw_input=""

_ran_any=false

if [[ -n "${_raw_input// }" ]]; then
    read -ra _selections <<< "$_raw_input"

    for _sel in "${_selections[@]}"; do
        case "$_sel" in
            1)
                section "show-info"
                bash "$SCRIPT_DIR/scripts/show-info.sh"
                _ran_any=true
                ;;
            2)
                section "set-wallpaper"
                bash "$SCRIPT_DIR/scripts/set-wallpaper.sh"
                _ran_any=true
                ;;
            3)
                section "nerd-fonts"
                # 42 = JetBrainsMono (1-based index in nerd-fonts.sh fonts_list)
                bash "$SCRIPT_DIR/scripts/nerd-fonts.sh" 42
                _ran_any=true
                ;;
            4)
                section "setup-zsh"
                bash "$SCRIPT_DIR/scripts/setup-zsh.sh"
                _ran_any=true
                ;;
            *)
                warn "Unknown selection '$_sel' — ignoring"
                ;;
        esac
    done
fi

[[ "$_ran_any" == true ]] || ok "No optional steps selected — skipping"

# ==============================================================================
# 8. Done  (_cleanup fires automatically via the EXIT trap)
# ==============================================================================

separator
printf "\n${BOLD}${GREEN}  All done!${RESET}\n"
printf "  ${DIM}Log out and back in (or reboot) to apply all changes.${RESET}\n\n"
