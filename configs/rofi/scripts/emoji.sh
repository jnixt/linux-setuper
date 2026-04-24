#!/bin/bash

# Path to your uploaded emoji list
EMOJI_FILE="$HOME/.config/rofi/scripts/emojis.txt"

selection=$(cat "$EMOJI_FILE" | rofi -dmenu -p " " -config ~/.config/rofi/emoji.rasi)

if [ -n "$selection" ]; then
  echo "$selection" | awk '{print $1}' | wl-copy && sleep 1 && wtype -M shift -k Insert -m shift
fi
