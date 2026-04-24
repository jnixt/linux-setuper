#!/usr/bin/env bash

# Source detector to load the SYS[] associative array
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detector.sh"

# --- Display detected system info ---
printf "%-18s: %s\n" "Distro"          "${SYS[DISTRO]}"
[[ -n "${SYS[DERIVATIVE]}" ]] && \
printf "%-18s: %s\n" "Derivative"      "${SYS[DERIVATIVE]}"
printf "%-18s: %s\n" "Package Manager" "${SYS[PM]}"
printf "%-18s: %s\n" "CPU"             "${SYS[CPU]}"
printf "%-18s: %s\n" "GPU"             "${SYS[GPU]}"
printf "%-18s: %s\n" "Form"            "${SYS[FORM]}"
printf "%-18s: %s\n" "${SYS[ENV_TYPE]}" "${SYS[ENV_NAME]}"
