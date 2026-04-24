#!/usr/bin/env bash

# ==============================================================================
#  set-wallpaper.sh
#  Universal wallpaper setter for Linux desktops and window managers.
#
#  Animated wallpapers (GIF) are used wherever swww is available (Wayland).
#  All other environments fall back to the static wallpaper.
#
#  Usage:
#    set-wallpaper.sh [OPTIONS]
#
#  Options:
#    -s, --static   PATH   Path to the static wallpaper image  (default: ~/.config/wallpapers/sukuna.png)
#    -a, --animated PATH   Path to the animated wallpaper (GIF) (default: ~/.config/wallpapers/silversurfer.gif)
#    -h, --help            Show this help message
#
#  Supported environments (auto-detected):
#    Wayland  — Hyprland (swww + hyprpaper), Sway (swww + swaybg), any wlroots WM (swww + swaybg)
#    X11 WMs  — i3, bspwm, openbox, awesome, qtile, dwm … (feh → nitrogen → xwallpaper)
#    DEs      — GNOME, KDE Plasma, XFCE, MATE, Cinnamon, LXDE, LXQt
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Defaults — resolved after dotfiles are installed
# ------------------------------------------------------------------------------
STATIC_WP="$HOME/.config/wallpapers/sukuna.png"
ANIMATED_WP="$HOME/.config/wallpapers/silversurfer.gif"

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------
usage() {
    grep '^#  ' "$0" | sed 's/^#  //'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--static)   STATIC_WP="$2";   shift 2 ;;
        -a|--animated) ANIMATED_WP="$2"; shift 2 ;;
        -h|--help)     usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { printf "  \033[36m•\033[0m  %s\n" "$*"; }
ok()   { printf "  \033[32m✔\033[0m  %s\n" "$*"; }
warn() { printf "  \033[33m⚠\033[0m  %s\n" "$*" >&2; }
die()  { printf "  \033[31m✖\033[0m  %s\n" "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------------------
# Validate wallpaper paths
# ------------------------------------------------------------------------------
[[ -f "$STATIC_WP" ]]   || die "Static wallpaper not found: $STATIC_WP"
[[ -f "$ANIMATED_WP" ]] || warn "Animated wallpaper not found: $ANIMATED_WP — will use static only"
HAVE_ANIMATED=false
[[ -f "$ANIMATED_WP" ]] && HAVE_ANIMATED=true

# ------------------------------------------------------------------------------
# Detect session type  (wayland / x11 / unknown)
# ------------------------------------------------------------------------------
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
[[ -n "${WAYLAND_DISPLAY:-}" ]] && SESSION_TYPE="wayland"
[[ -n "${DISPLAY:-}" && -z "$SESSION_TYPE" ]] && SESSION_TYPE="x11"
SESSION_TYPE="${SESSION_TYPE,,}"   # lowercase

# ------------------------------------------------------------------------------
# Detect desktop / WM name
# Prefer XDG_CURRENT_DESKTOP → XDG_SESSION_DESKTOP → DESKTOP_SESSION → pgrep
# ------------------------------------------------------------------------------
DESKTOP="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"

if [[ -z "$DESKTOP" ]]; then
    # Nothing set by the session manager — scan running processes
    for wm in Hyprland sway river labwc wayfire i3 bspwm openbox awesome qtile xmonad dwm; do
        if pgrep -x "$wm" >/dev/null 2>&1; then
            DESKTOP="$wm"
            break
        fi
    done
fi

DESKTOP_LOWER="${DESKTOP,,}"

log "Session type : ${SESSION_TYPE:-unknown}"
log "Desktop/WM   : ${DESKTOP:-unknown}"
log "Static WP    : $STATIC_WP"
$HAVE_ANIMATED && log "Animated WP  : $ANIMATED_WP"

# ==============================================================================
# --- SETTER FUNCTIONS ---------------------------------------------------------
# ==============================================================================

# --- swww (animated-capable, any wlroots Wayland compositor) ------------------
_set_swww() {
    local wp="$1"
    if ! has swww; then
        warn "swww not found — skipping animated wallpaper"
        return 1
    fi

    # Start daemon only if it isn't already running
    if ! swww query >/dev/null 2>&1; then
        log "Starting swww-daemon…"
        swww-daemon --no-cache &
        # Give it a moment to bind its socket
        local retries=0
        until swww query >/dev/null 2>&1 || (( retries++ >= 20 )); do
            sleep 0.1
        done
    fi

    swww img "$wp" \
        --transition-type simple \
        --transition-duration 0.2 \
        --transition-fps 67
    ok "Wallpaper set via swww: $(basename "$wp")"
}

# --- hyprpaper (Hyprland static fallback via IPC) -----------------------------
_set_hyprpaper() {
    local wp="$1"
    if ! has hyprctl; then
        warn "hyprctl not found — cannot use hyprpaper IPC"
        return 1
    fi

    # Preload then apply to all monitors
    hyprctl hyprpaper preload "$wp" 2>/dev/null || true
    # Get every connected monitor name and apply individually
    while IFS= read -r monitor; do
        hyprctl hyprpaper wallpaper "$monitor,$wp" 2>/dev/null || true
    done < <(hyprctl monitors -j 2>/dev/null | grep -oP '"name":\s*"\K[^"]+')

    ok "Wallpaper set via hyprpaper IPC: $(basename "$wp")"
}

# --- swaybg (Sway / generic Wayland, static only) ----------------------------
_set_swaybg() {
    local wp="$1"
    if ! has swaybg; then
        warn "swaybg not found"
        return 1
    fi
    pkill swaybg 2>/dev/null || true
    swaybg -i "$wp" -m fill &
    disown
    ok "Wallpaper set via swaybg: $(basename "$wp")"
}

# --- feh (X11 WMs) ------------------------------------------------------------
_set_feh() {
    local wp="$1"
    if ! has feh; then return 1; fi
    feh --bg-fill "$wp"
    ok "Wallpaper set via feh: $(basename "$wp")"
}

# --- nitrogen (X11 WMs) -------------------------------------------------------
_set_nitrogen() {
    local wp="$1"
    if ! has nitrogen; then return 1; fi
    nitrogen --set-zoom-fill --save "$wp"
    ok "Wallpaper set via nitrogen: $(basename "$wp")"
}

# --- xwallpaper (X11 WMs, last resort) ----------------------------------------
_set_xwallpaper() {
    local wp="$1"
    if ! has xwallpaper; then return 1; fi
    xwallpaper --zoom "$wp"
    ok "Wallpaper set via xwallpaper: $(basename "$wp")"
}

# --- GNOME --------------------------------------------------------------------
_set_gnome() {
    local wp="$1"
    local uri="file://$wp"
    gsettings set org.gnome.desktop.background picture-uri      "$uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
    gsettings set org.gnome.desktop.background picture-options  "zoom"
    ok "Wallpaper set via gsettings (GNOME): $(basename "$wp")"
}

# --- KDE Plasma ---------------------------------------------------------------
_set_kde() {
    local wp="$1"
    # Prefer the dedicated helper (Plasma 5.26+)
    if has plasma-apply-wallpaperimage; then
        plasma-apply-wallpaperimage "$wp"
        ok "Wallpaper set via plasma-apply-wallpaperimage: $(basename "$wp")"
        return 0
    fi

    # Fallback: qdbus / qdbus6 script that covers all desktops
    local dbus_cmd=""
    has qdbus6 && dbus_cmd="qdbus6"
    has qdbus  && dbus_cmd="${dbus_cmd:-qdbus}"

    if [[ -n "$dbus_cmd" ]]; then
        local script
        script=$(cat <<KDESCRIPT
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://$wp");
}
KDESCRIPT
)
        $dbus_cmd org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "$script"
        ok "Wallpaper set via qdbus (KDE Plasma): $(basename "$wp")"
        return 0
    fi

    warn "Neither plasma-apply-wallpaperimage nor qdbus found — KDE wallpaper not set"
    return 1
}

# --- XFCE ---------------------------------------------------------------------
_set_xfce() {
    local wp="$1"
    if ! has xfconf-query; then
        warn "xfconf-query not found"
        return 1
    fi

    # Iterate every workspace/monitor last-image property dynamically
    local count=0
    while IFS= read -r prop; do
        xfconf-query -c xfce4-desktop -p "$prop" -s "$wp" 2>/dev/null || \
        xfconf-query -c xfce4-desktop -p "$prop" --create -t string -s "$wp" 2>/dev/null || true

        # Also force "zoomed" style (5) on the matching image-style property
        local style_prop="${prop/last-image/image-style}"
        xfconf-query -c xfce4-desktop -p "$style_prop" -s 5 2>/dev/null || \
        xfconf-query -c xfce4-desktop -p "$style_prop" --create -t int -s 5 2>/dev/null || true

        (( count++ )) || true
    done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$')

    if [[ $count -eq 0 ]]; then
        warn "No XFCE wallpaper properties found — is xfdesktop running?"
        return 1
    fi

    ok "Wallpaper set via xfconf-query (XFCE, ${count} output(s)): $(basename "$wp")"
}

# --- MATE ---------------------------------------------------------------------
_set_mate() {
    local wp="$1"
    gsettings set org.mate.background picture-filename "$wp"
    gsettings set org.mate.background picture-options  "zoom"
    ok "Wallpaper set via gsettings (MATE): $(basename "$wp")"
}

# --- Cinnamon -----------------------------------------------------------------
_set_cinnamon() {
    local wp="$1"
    gsettings set org.cinnamon.desktop.background picture-uri     "file://$wp"
    gsettings set org.cinnamon.desktop.background picture-options "zoom"
    ok "Wallpaper set via gsettings (Cinnamon): $(basename "$wp")"
}

# --- LXDE ---------------------------------------------------------------------
_set_lxde() {
    local wp="$1"
    if ! has pcmanfm; then
        warn "pcmanfm not found"
        return 1
    fi
    pcmanfm --set-wallpaper="$wp" --wallpaper-mode=crop
    ok "Wallpaper set via pcmanfm (LXDE): $(basename "$wp")"
}

# --- LXQt ---------------------------------------------------------------------
_set_lxqt() {
    local wp="$1"
    if ! has pcmanfm-qt; then
        warn "pcmanfm-qt not found"
        return 1
    fi
    pcmanfm-qt --set-wallpaper="$wp" --wallpaper-mode=zoom
    ok "Wallpaper set via pcmanfm-qt (LXQt): $(basename "$wp")"
}

# --- Generic Wayland fallback -------------------------------------------------
_set_wayland_generic() {
    local wp="$1"
    _set_swaybg "$wp"
}

# --- Generic X11 fallback (try tools in order of preference) -----------------
_set_x11_generic() {
    local wp="$1"
    _set_feh "$wp"       && return 0
    _set_nitrogen "$wp"  && return 0
    _set_xwallpaper "$wp" && return 0
    warn "No X11 wallpaper setter found (tried feh, nitrogen, xwallpaper)"
    return 1
}

# ==============================================================================
# --- DISPATCH -----------------------------------------------------------------
# Prefer animated wallpaper on environments that support it (swww).
# Fall back to static for everything else.
# ==============================================================================

chose_animated=false

case "$DESKTOP_LOWER" in

    # --------------------------------------------------------------------------
    # Hyprland
    # --------------------------------------------------------------------------
    *hyprland*)
        if $HAVE_ANIMATED && has swww; then
            _set_swww "$ANIMATED_WP"
            chose_animated=true
        else
            # swww unavailable or no GIF — try hyprpaper, then swaybg
            _set_hyprpaper "$STATIC_WP" 2>/dev/null \
                || _set_swaybg "$STATIC_WP" \
                || die "Could not set wallpaper on Hyprland"
        fi
        ;;

    # --------------------------------------------------------------------------
    # Sway
    # --------------------------------------------------------------------------
    *sway*)
        if $HAVE_ANIMATED && has swww; then
            # swww works on Sway (wlroots)
            _set_swww "$ANIMATED_WP"
            chose_animated=true
        else
            _set_swaybg "$STATIC_WP" \
                || die "Could not set wallpaper on Sway"
        fi
        ;;

    # --------------------------------------------------------------------------
    # Other wlroots-based WMs (river, labwc, wayfire, niri, …)
    # --------------------------------------------------------------------------
    *river*|*labwc*|*wayfire*|*niri*|*hikari*)
        if $HAVE_ANIMATED && has swww; then
            _set_swww "$ANIMATED_WP"
            chose_animated=true
        else
            _set_wayland_generic "$STATIC_WP" \
                || die "Could not set wallpaper on Wayland WM ($DESKTOP)"
        fi
        ;;

    # --------------------------------------------------------------------------
    # GNOME / GNOME-based (Ubuntu, Pop!_OS, Fedora Workstation, …)
    # --------------------------------------------------------------------------
    *gnome*|*ubuntu*|*pop*|*budgie*|*unity*)
        _set_gnome "$STATIC_WP" \
            || die "Could not set wallpaper on GNOME"
        ;;

    # --------------------------------------------------------------------------
    # KDE Plasma
    # --------------------------------------------------------------------------
    *kde*|*plasma*)
        _set_kde "$STATIC_WP" \
            || die "Could not set wallpaper on KDE Plasma"
        ;;

    # --------------------------------------------------------------------------
    # XFCE
    # --------------------------------------------------------------------------
    *xfce*)
        _set_xfce "$STATIC_WP" \
            || die "Could not set wallpaper on XFCE"
        ;;

    # --------------------------------------------------------------------------
    # MATE
    # --------------------------------------------------------------------------
    *mate*)
        _set_mate "$STATIC_WP" \
            || die "Could not set wallpaper on MATE"
        ;;

    # --------------------------------------------------------------------------
    # Cinnamon
    # --------------------------------------------------------------------------
    *cinnamon*)
        _set_cinnamon "$STATIC_WP" \
            || die "Could not set wallpaper on Cinnamon"
        ;;

    # --------------------------------------------------------------------------
    # LXDE
    # --------------------------------------------------------------------------
    *lxde*)
        _set_lxde "$STATIC_WP" \
            || die "Could not set wallpaper on LXDE"
        ;;

    # --------------------------------------------------------------------------
    # LXQt
    # --------------------------------------------------------------------------
    *lxqt*)
        _set_lxqt "$STATIC_WP" \
            || die "Could not set wallpaper on LXQt"
        ;;

    # --------------------------------------------------------------------------
    # X11 WMs (i3, bspwm, openbox, awesome, qtile, xmonad, dwm, …)
    # --------------------------------------------------------------------------
    *i3*|*bspwm*|*openbox*|*awesome*|*qtile*|*xmonad*|*dwm*|*fluxbox*|*icewm*)
        _set_x11_generic "$STATIC_WP" \
            || die "Could not set wallpaper on X11 WM ($DESKTOP)"
        ;;

    # --------------------------------------------------------------------------
    # Unknown — best-effort based on session type
    # --------------------------------------------------------------------------
    *)
        warn "Unknown desktop/WM '$DESKTOP' — attempting best-effort detection"
        if [[ "$SESSION_TYPE" == "wayland" ]]; then
            if $HAVE_ANIMATED && has swww; then
                _set_swww "$ANIMATED_WP" && chose_animated=true
            else
                _set_wayland_generic "$STATIC_WP" \
                    || die "No Wayland wallpaper setter found (tried swww, swaybg)"
            fi
        elif [[ "$SESSION_TYPE" == "x11" ]]; then
            _set_x11_generic "$STATIC_WP" \
                || die "No X11 wallpaper setter found (tried feh, nitrogen, xwallpaper)"
        else
            die "Cannot detect session type or desktop environment. Set XDG_CURRENT_DESKTOP or WAYLAND_DISPLAY/DISPLAY."
        fi
        ;;
esac

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
if $chose_animated; then
    ok "Done — animated wallpaper active"
else
    ok "Done — static wallpaper active"
fi
