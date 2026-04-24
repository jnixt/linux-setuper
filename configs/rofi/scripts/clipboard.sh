#!/bin/bash

MODE=$1

if [ "$MODE" == "img" ]; then
  selection=$(cliphist list | grep -a '\[\[ binary data' | while read -r line; do
    ID=$(echo "$line" | cut -f1)
    echo "$line" | cliphist decode >"/tmp/rofi_cliphist/$ID.png"
    echo -en "$ID\0icon\x1f/tmp/rofi_cliphist/$ID.png\n"
  done | rofi -dmenu -config ~/.config/rofi/clipboardi.rasi)
elif [ "$MODE" == "txt" ]; then
  selection=$(cliphist list | grep -v "\[\[ binary data" | sed 's/^[0-9]*[[:space:]]*//' | rofi -dmenu -p " " -config ~/.config/rofi/clipboardt.rasi)
else
  (
    echo "Couting down to secret.." && echo "" && echo "" && for i in {1..66}; do echo "We are $((67 - i)) away from secret.."; done && echo "" && echo "" && echo "" &&
      echo "Secret reached.." && for i in {0..67}; do echo "67!!!!!"; done
  ) | rofi -dmenu -theme-str 'configuration {show-icons: false;} listview {cycle: false;} inputbar {enabled: false;} #scrollbar {width: 0; border-radius: 8px; handle-width: 3px; handle-color: transparent;}'
fi

# Execution logic
if [ -n "$selection" ]; then
  cliphist list | grep "$selection" | cliphist decode | wl-copy && sleep 0.3 && wtype -M shift -k Insert -m shift
fi
