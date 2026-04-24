#!/bin/bash

# Define the raw icons
shutdown="⏻"
reboot=""
sleep=""
logout="󰍃"
lock=""

if [ -z "$1" ]; then
  echo -e "$shutdown\n$reboot\n$sleep\n$logout\n$lock"
else
  selection="$1"
  case "$selection" in
  "$shutdown")
    systemctl poweroff
    ;;
  "$reboot")
    systemctl reboot
    ;;
  "$sleep")
    systemctl suspend
    ;;
  "$logout")
    hyprctl dispatch exit
    ;;
  "$lock")
    hyprlock
    ;;
  esac
  exit 0
fi
