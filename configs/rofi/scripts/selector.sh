#!/bin/bash

# Define the raw icons
drun=""
run=""
filebrowser="󰉋"
window=""
clipboardt=""
clipboardi=""
emoji=""
powermenu="󰐥"
ssh=""
combi="󰽜"
keys=""
recursivebrowser="󰕇"
selector=""

#!/bin/bash

# ... (your icon definitions) ...

if [ -z "$1" ]; then
  echo -e "$drun\n$run\n$filebrowser\n$powermenu\n$window\n$clipboardt\n$clipboardi\n$emoji"
else
  selection="$1"
  case "$selection" in
  "$drun")
    setsid -f sh -c "killall rofi; sleep 0.05; rofi -show drun -config '~/.config/rofi/drun.rasi'" &
    ;;
  "$run")
    setsid -f sh -c "killall rofi; sleep 0.05; rofi -show run -config '~/.config/rofi/run.rasi'" &
    ;;
  "$filebrowser")
    setsid -f sh -c "killall rofi; sleep 0.05; rofi -show filebrowser -config '~/.config/rofi/filebrowser.rasi'" &
    ;;
  "$powermenu")
    setsid -f sh -c "killall rofi; sleep 0.05; rofi -show powermenu -config '~/.config/rofi/powermenu.rasi'" &
    ;;
  "$window")
    setsid -f sh -c "killall rofi; sleep 0.05; rofi -show window -config '~/.config/rofi/window.rasi'" &
    ;;
  "$clipboardt")
    setsid -f sh -c "killall rofi; sleep 0.05; ~/.config/rofi/scripts/clipboard.sh txt" &
    ;;
  "$clipboardi")
    setsid -f sh -c "killall rofi; sleep 0.05; ~/.config/rofi/scripts/clipboard.sh img" &
    ;;
  "$emoji")
    setsid -f sh -c "killall rofi; sleep 0.05; ~/.config/rofi/scripts/emoji.sh" &
    ;;
  esac
  exit 0
fi
