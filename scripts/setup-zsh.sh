#!/usr/bin/env bash

# ==============================================================================
#  setup-zsh.sh
#  Configures Zsh: installs Oh My Zsh, plugins, updates .zshrc, and sets
#  Zsh as the default shell.
#
#  Assumes zsh, git, and curl are already installed by the main installer.
#  Safe to re-run — all steps are idempotent.
# ==============================================================================

set -euo pipefail

# --- Helpers ------------------------------------------------------------------
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log()  { printf "  ${CYAN}•${RESET}  %s\n" "$*"; }
ok()   { printf "  ${GREEN}✔${RESET}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %s\n" "$*"; }
die()  { printf "  ${RED}✖${RESET}  %s\n" "$*" >&2; exit 1; }

separator() { printf "${BOLD}%s${RESET}\n" "────────────────────────────────────────"; }

# --- Pre-flight checks --------------------------------------------------------
separator
printf "${BOLD}  Zsh Setup${RESET}\n"
separator

command -v zsh  >/dev/null 2>&1 || die "zsh is not installed. Install it via the main installer first."
command -v git  >/dev/null 2>&1 || die "git is not installed. Install it via the main installer first."
command -v curl >/dev/null 2>&1 || die "curl is not installed. Install it via the main installer first."

ZSH_PATH="$(command -v zsh)"
ok "zsh found at $ZSH_PATH"

# --- Oh My Zsh ----------------------------------------------------------------
OMZ_DIR="$HOME/.oh-my-zsh"

if [[ -d "$OMZ_DIR" ]]; then
    ok "Oh My Zsh already installed — skipping"
else
    log "Installing Oh My Zsh…"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed"
fi

# --- Plugins ------------------------------------------------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

clone_plugin() {
    local repo="$1"
    local name="$2"
    local dest="$ZSH_CUSTOM/plugins/$name"

    if [[ -d "$dest" ]]; then
        ok "Plugin already present — $name"
    else
        log "Cloning $name…"
        git clone --depth 1 "$repo" "$dest"
        ok "Plugin installed — $name"
    fi
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions"              "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting"           "zsh-syntax-highlighting"
clone_plugin "https://github.com/zdharma-continuum/fast-syntax-highlighting"  "fast-syntax-highlighting"
clone_plugin "https://github.com/marlonrichert/zsh-autocomplete"              "zsh-autocomplete"

# --- .zshrc -------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

log "Configuring $ZSHRC…"

# Theme
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="candy"/' "$ZSHRC"
else
    echo 'ZSH_THEME="candy"' >> "$ZSHRC"
fi

# Plugin line
PLUGIN_LINE='plugins=(zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)'

if grep -q '^plugins=' "$ZSHRC"; then
    sed -i "s/^plugins=.*/$PLUGIN_LINE/" "$ZSHRC"
else
    echo "$PLUGIN_LINE" >> "$ZSHRC"
fi

ok ".zshrc updated"

# --- Default shell ------------------------------------------------------------
if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    ok "Zsh is already the default shell"
elif command -v chsh >/dev/null 2>&1; then
    log "Setting Zsh as default shell…"
    chsh -s "$ZSH_PATH" || warn "chsh failed — change shell manually: chsh -s $ZSH_PATH"
    ok "Default shell set to $ZSH_PATH"
else
    warn "chsh not available — change shell manually: chsh -s $ZSH_PATH"
fi

# --- Done ---------------------------------------------------------------------
separator
ok "Zsh setup complete — restart your terminal or run: exec zsh"
separator
