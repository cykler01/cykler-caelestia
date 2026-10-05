#!/usr/bin/env bash
#
# Picks a colour from anywhere on screen and copies its hex code to the
# clipboard. Backs the launcher's `>colourpicker` action, alongside ocr.sh and
# lens.sh.

if ! command -v hyprpicker >/dev/null 2>&1; then
    notify-send -a caelestia-shell -u low "Colour picker" "hyprpicker is not installed"
    exit 1
fi

# -a copies the colour to the clipboard, -n keeps ANSI colour codes out of
# stdout so it can be shown in the notification, and a non-zero exit means the
# picker was cancelled (Escape), which we swallow silently.
colour=$(hyprpicker -a -n -f hex) || exit 0
[ -n "$colour" ] || exit 0

notify-send -a caelestia-shell "Colour picker" "$colour copied to clipboard"
