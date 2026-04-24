#!/usr/bin/env bash

# ==============================================================================
#  apply-configs.sh
#  Deploys dotfiles and assets to their correct locations.
#
#  - configs/<name>/          →  ~/.config/<name>/
#  - cursors/                 →  ~/.icons/
#  - distro-specific/hypr/    →  ~/.config/hypr/   (Hyprland only)
#
#  Backs up any pre-existing non-empty destination before overwriting.
#  Safe to re-run.
#
#  Usage:
#    bash scripts/apply-configs.sh
#    or called from install.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Load SYS[] if not already populated ------------------------------------
if [[ ! -v SYS ]]; then
    source "$SCRIPT_DIR/detector.sh"
fi

# --- Helpers ----------------------------------------------------------------
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

log()       { printf "  ${CYAN}•${RESET}  %s\n" "$*"; }
ok()        { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
warn()      { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; }
section()   { printf "\n${BOLD}  %s${RESET}\n${DIM}%s${RESET}\n" "$1" "────────────────────────────────────────"; }
has()       { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------
# _deploy <label> <src-dir> <dst-dir>
#   Copies the *contents* of <src-dir> into <dst-dir>.
#   Creates a timestamped .bak of any pre-existing non-empty <dst-dir>.
# ----------------------------------------------------------------------------
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

# ============================================================
section "Deploying Configs"
# ============================================================

# ── configs/<name>/ → ~/.config/<name>/ ─────────────────────────────────────
if [[ -d "$REPO_DIR/configs" ]]; then
    for _cfg in "$REPO_DIR/configs"/*/; do
        _cfg_name="$(basename "$_cfg")"
        _deploy "$_cfg_name" "$_cfg" "$HOME/.config/$_cfg_name"
    done
else
    warn "configs/ directory not found — skipping"
fi

# ── cursors/ → ~/.icons/ ────────────────────────────────────────────────────
_deploy "cursors" "$REPO_DIR/cursors" "$HOME/.icons"

# ── distro-specific/hypr/ → ~/.config/hypr/ (Hyprland only) ─────────────────
if [[ "${SYS[ENV_NAME],,}" == *hyprland* ]]; then
    _deploy "hyprland config" \
        "$REPO_DIR/distro-specific/hypr" \
        "$HOME/.config/hypr"
else
    log "Hyprland not detected — skipping distro-specific/hypr"
fi

# ============================================================
section "Fastfetch Helpers"
# ============================================================

# Make custom scripts executable and symlink into PATH
mkdir -p "$HOME/.local/bin"

for _exe in count-packages get-splash; do
    _exe_src="$HOME/.config/fastfetch/$_exe"
    if [[ -f "$_exe_src" ]]; then
        chmod +x "$_exe_src"
        ln -sf "$_exe_src" "$HOME/.local/bin/$_exe"
        ok "$_exe  →  ~/.local/bin/$_exe"
    fi
done

# ── Ensure ~/.local/bin is in PATH ──────────────────────────────────────────
for _rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$_rc" ]] && ! grep -q '\.local/bin' "$_rc"; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$_rc"
        ok "Added ~/.local/bin to PATH  ($(basename "$_rc"))"
    fi
done

printf "\n${DIM}%s${RESET}\n" "────────────────────────────────────────"
ok "Config deployment complete"
