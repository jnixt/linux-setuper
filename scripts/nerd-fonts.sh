#!/bin/bash
# Nerd Fonts Installer (Batch सक्षम 🚀)

echo "🎯 Nerd Fonts Installer"
echo "========================="

fonts_list=("0xProto" "3270" "AdwaitaMono" "Agave" "AnonymousPro" "Arimo" "AtkinsonHyperlegibleMono" "AurulentSansMono" "BigBlueTerminal" "BitstreamVeraSansMono" "CascadiaCode" "CascadiaMono" "CodeNewRoman" "ComicShannsMono" "CommitMono" "Cousine" "D2Coding" "DaddyTimeMono" "DejaVuSansMono" "DepartureMono" "DroidSansMono" "EnvyCodeR" "FantasqueSansMono" "FiraCode" "FiraMono" "GeistMono" "Go-Mono" "Gohu" "Hack" "Hasklig" "HeavyData" "Hermit" "iA-Writer" "IBMPlexMono" "Inconsolata" "InconsolataGo" "InconsolataLGC" "IntelOneMono" "Iosevka" "IosevkaTerm" "IosevkaTermSlab" "JetBrainsMono" "Lekton" "LiberationMono" "Lilex" "MartianMono" "Meslo" "Monaspace" "Monofur" "Monoid" "Mononoki" "MPlus" "NerdFontsSymbolsOnly" "Noto" "OpenDyslexic" "Overpass" "ProFont" "ProggyClean" "Recursive" "RobotoMono" "ShareTechMono" "SourceCodePro" "SpaceMono" "Terminus" "Tinos" "Ubuntu" "UbuntuMono" "UbuntuSans" "VictorMono" "ZedMono")

install_font() {
    local font_name="$1"
    local zip_file="${font_name}.zip"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Skip if already installed
    if [ -d "$HOME/.fonts/$font_name" ]; then
        echo "⏭️  Skipping '${font_name}' (already installed)"
        return
    fi

    echo ""
    echo "⬇️  Installing '${font_name}'..."

    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
    echo "🔗 $url"

    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$zip_file" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$zip_file" "$url"
    else
        echo "❌ Error: 'curl' or 'wget' is required."
        exit 1
    fi

    mkdir -p "$HOME/.fonts/$font_name"

    echo "📦 Extracting..."
    unzip -q "$zip_file" -d "$tmp_dir"

    echo "🚚 Moving files..."
    mv "$tmp_dir"/* "$HOME/.fonts/$font_name/"

    echo "🧹 Cleaning up..."
    rm -rf "$zip_file" "$tmp_dir"

    echo "✅ '${font_name}' installed!"
}

refresh_cache() {
    echo ""
    echo "🔄 Refreshing font cache..."
    fc-cache -fv >/dev/null
    echo "✨ Done!"
}

process_selection() {
    local selections=("$@")

    for num in "${selections[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            index=$((num - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#fonts_list[@]}" ]; then
                install_font "${fonts_list[$index]}"
            else
                echo "⚠️  Invalid number: $num"
            fi
        else
            echo "⚠️  Not a number: $num"
        fi
    done

    refresh_cache
}

# --- CLI mode ---
if [ "$#" -gt 0 ]; then
    echo "⚡ Batch mode: Installing fonts $*"
    process_selection "$@"

# --- Interactive mode ---
else
    echo "📚 Available Nerd Fonts:"
    for i in "${!fonts_list[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${fonts_list[$i]}"
    done

    echo ""
    echo "💡 Tip: You can select multiple fonts (e.g. 1 5 10)"
    read -rp "👉 Enter selection(s): " -a user_choices

    if [ "${#user_choices[@]}" -eq 0 ]; then
        echo "❌ No selection made. Exiting."
        exit 1
    fi

    process_selection "${user_choices[@]}"
fi

echo ""
echo "🎉 All done! Enjoy your fonts 😎"
