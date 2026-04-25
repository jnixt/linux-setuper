<br>

```
     ██╗███╗   ██╗██╗██╗  ██╗████████╗
     ██║████╗  ██║██║╚██╗██╔╝╚══██╔══╝
     ██║██╔██╗ ██║██║ ╚███╔╝    ██║
██   ██║██║╚██╗██║██║ ██╔██╗    ██║
╚█████╔╝██║ ╚████║██║██╔╝ ██╗   ██║
 ╚════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝   ╚═╝
```

> *my configs. my rules. one script.*

<br>

---

## What is this?

This is my personal dotfile repository — configs for every tool I use, wired up to a single `install.sh` that figures out where it's running and sets everything up correctly. I distro-hop a lot, so the goal is to sit down on a fresh install, run one command, and end up with my exact setup without having to remember what goes where.

The installer detects your distro, package manager, desktop environment or window manager, CPU, GPU, and form factor before doing anything — then uses that to make smart decisions about what to install and how.

<br>

---

## Quick Start


Using curl:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jnixt/linux-setuper/main/install.sh)"
```

Or with wget:

```sh
bash -c "$(wget -qO- https://raw.githubusercontent.com/jnixt/linux-setuper/main/install.sh)"
```

> Do **not** run as root. The script will ask for your sudo password once and keep it alive for the full install.

<br>
    
---

## Features

- **One-command setup** — clone and run, everything else is handled
- **Distro-aware** — tested across Arch, Debian/Ubuntu, Fedora, and openSUSE
- **Environment-aware** — detects your WM or DE and only installs what makes sense for it
- **Sealed detection** — all system info lives inside a single `SYS[]` array, no global variable pollution
- **Idempotent** — safe to re-run; already-installed packages and configs are skipped
- **Animated wallpapers** — `swww` for Wayland compositors with a static `hyprpaper` fallback
- **Graceful fallbacks** — if a package isn't in your distro's repos, the script tries alternative sources (AUR, Flatpak, GitHub releases, cargo)
- **Sudo once** — credentials are cached and kept alive; you're never prompted twice

<br>

---

## Supported Environments

| Type | Name |
|---|---|
| **Wayland WM** | Hyprland *(primary)*, Sway, river, labwc, niri, wayfire |
| **X11 WM** | i3, bspwm, openbox, awesome, qtile, xmonad, dwm |
| **DE** | GNOME, KDE Plasma, XFCE, MATE, Cinnamon, LXDE, LXQt |

| Distro family | Package manager |
|---|---|
| Arch / EndeavourOS / Manjaro | `pacman` + `yay` |
| Ubuntu / Debian / Pop!\_OS | `apt` |
| Fedora / RHEL | `dnf` |
| openSUSE Leap / Tumbleweed | `zypper` |

<br>

---

## Project Structure

```
linux-setuper/
│
├── install.sh                  # Entry point — run this
│
├── scripts/
│   ├── detector.sh             # Detects distro, PM, CPU, GPU, WM/DE → SYS[]
│   ├── show-info.sh            # Pretty-prints detected system info
│   ├── install-packages.sh     # Full cross-distro package installer
│   ├── setup-zsh.sh            # Oh My Zsh + plugins + .zshrc config
│   ├── set-wallpaper.sh        # Universal wallpaper setter for all envs
│   └── nerd-fonts.sh           # Interactive/batch Nerd Fonts installer
│
├── configs/                    # Dotfiles (DE/WM-agnostic)
│   ├── fastfetch/
│   │   ├── config.jsonc        # Fastfetch layout and modules
│   │   ├── count-packages      # Cross-distro package counter (used by fastfetch)
│   │   └── get-splash          # Splash quote (hyprctl splash or built-in fallback)
│   ├── kitty/                  # Terminal emulator config
│   ├── micro/                  # Micro editor config
│   ├── rofi/                   # App launcher config + scripts
│   ├── yazi/                   # File manager config
│   └── wallpapers/
│       ├── sukuna.png          # Static wallpaper
│       └── silversurfer.gif    # Animated wallpaper (swww)
│
├── distro-specific/
│   └── hypr/                   # Hyprland-only configs
│       ├── hyprland.conf
│       └── hyprpaper.conf
│
├── packages/                     # Extra binaries that can't be installed by Package Managr
└── cursors/                      # Cursor pack
│   └──  UOS-Dark
```

<br>

---

## Packages

### Core — installed everywhere

| Package | Purpose |
|---|---|
| `zsh` | Shell |
| `git` `curl` `wget` | The holy trinity |
| `vim` | Because it's always there when you need it |
| `tmux` | Terminal multiplexer |
| `ncdu` | Disk usage, the good way |
| `btop` | System monitor |
| `kitty` | Terminal emulator |
| `micro` | Sane terminal editor |
| `fastfetch` | System info |
| `firefox` | Browser |
| `7zip` | Archive tool |
| `openssh` | SSH client |
| `tailscale` | Mesh VPN |
| `yazi` | Terminal file manager |
| `zed` | Editor |
| `torbrowser-launcher` | Tor Browser |

### WM-only (`rofi`)

Installed when a window manager is detected. On Wayland + Arch, `rofi-wayland` is used instead of vanilla `rofi`.

### Arch-only (`yay`)

The AUR helper is built from source using `makepkg`. Subsequent AUR packages (`swww`, `hyprpaper`, `rofi-wayland`, `hyprshot`, `mission-center`) are installed through it.

### Hyprland-specific

Only installed when Hyprland is the detected compositor:

| Package | Purpose |
|---|---|
| `wl-clipboard` | Wayland clipboard |
| `cliphist` | Clipboard history daemon |
| `brightnessctl` | Backlight control |
| `playerctl` | Media key control |
| `hyprshot` | Screenshot tool (AUR) |
| `gpicview` | Image viewer for screenshots |
| `upower` | Battery info |
| `missioncenter` | GUI task manager (AUR / Flatpak) |

### Wallpaper tools

| Environment | Tool |
|---|---|
| Wayland (any) | `swww` — animated GIF support |
| Wayland fallback | `swaybg` — static only |
| Hyprland fallback | `hyprpaper` |
| X11 | `feh` → `nitrogen` → `xwallpaper` |

<br>

---

## Zsh Setup

Running `install.sh` will also:

1. Install **Oh My Zsh** (skipped if already present)
2. Clone these plugins:
   - `zsh-autosuggestions`
   - `zsh-syntax-highlighting`
   - `fast-syntax-highlighting`
   - `zsh-autocomplete`
3. Set `ZSH_THEME="candy"` and wire up the plugins in `.zshrc`
4. Set Zsh as the default shell via `chsh`

<br>

---

## Wallpapers

| File | Type | Used by |
|---|---|---|
| `sukuna.png` | Static | `hyprpaper`, all non-Wayland envs |
| `silversurfer.gif` | Animated | `swww` on Wayland |

The `set-wallpaper.sh` script auto-detects the current environment and picks the right setter. Custom paths can be passed with `--static` and `--animated`.

<br>

---

## Nerd Fonts

The `nerd-fonts.sh` script can install any font from the Nerd Fonts release catalog, individually or in bulk.

```sh
# Interactive picker
bash scripts/nerd-fonts.sh

# Batch — install by index number
bash scripts/nerd-fonts.sh 22 34 51
```

<br>

---

## System Detection

Before anything runs, `detector.sh` populates the `SYS[]` associative array:

```sh
source scripts/detector.sh

echo "${SYS[DISTRO]}"    # Arch Linux
echo "${SYS[PM]}"        # pacman
echo "${SYS[FORM]}"      # Laptop
echo "${SYS[ENV_NAME]}"  # Hyprland
echo "${SYS[CPU]}"       # AMD Ryzen 5 5500U with Radeon Graphics
echo "${SYS[GPU]}"       # AMD/ATI
```

Run `show-info.sh` to print a summary of everything detected on the current machine.

<br>

---

<div align="center">
  <sub>built for myself · shared for whoever needs it</sub>
</div>
