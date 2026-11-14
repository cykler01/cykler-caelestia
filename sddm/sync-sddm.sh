#!/usr/bin/env bash
# sync-sddm.sh [--check] [--missing]
#
# paints the login screen from the palette the shell is wearing. sddm runs
# before anyone logs in, so it cannot read a per-user palette -- the colours
# have to live in the theme itself, under users/<account>/, which
# install-theme.sh leaves world-writable for exactly this.
#
# the shell's scheme is plain json (state/caelestia/scheme.json), so unlike
# lucid's version of this script there is nothing to ask the running shell:
# the file is the whole truth and this works with the shell stopped.
#
# --missing paints only an account the greeter has nothing for yet, for running
#           at login so a new account shows up as itself straight away
# --check   reports what would happen and writes nothing:
#             ok <theme>       ours, writable, will follow the palette
#             other <theme>    another theme is current; nothing to paint
#             readonly <path>  ours, but not writable by this account
#             notheme          sddm is not configured, or its theme is gone
#             noscheme         the shell has not written a palette yet

set -euo pipefail

CHECK=0
MISSING=0
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --check) CHECK=1 ;;
        --missing) MISSING=1 ;;
        *) break ;;
    esac
    shift
done

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
SCHEME="$STATE/scheme.json"
THEMES=/usr/share/sddm/themes
ME="$(id -un)"

# the theme sddm shows: the last conf.d file to set Current wins, and
# /etc/sddm.conf is read before any of them
current_theme() {
    local f line name=""
    for f in /etc/sddm.conf /etc/sddm.conf.d/*.conf; do
        [[ -f $f ]] || continue
        line=$(sed -n '/^\[Theme\]/,/^\[/s/^[[:space:]]*Current=//p' "$f" | tail -1)
        [[ -n $line ]] && name=$(echo "$line" | tr -d '[:space:]')
    done
    printf '%s' "$name"
}

THEME=$(current_theme)
DIR="$THEMES/$THEME"

if [[ -z $THEME || ! -f "$DIR/theme.conf" ]]; then
    [[ $CHECK -eq 1 ]] && echo notheme
    exit 0
fi

# ours, or somebody else's
if ! grep -qs '^Theme-Id=cykler-caelestia$\|^Name=cykler-caelestia$' "$DIR/metadata.desktop"; then
    [[ $CHECK -eq 1 ]] && echo "other $THEME"
    exit 0
fi

MINE="$DIR/users/$ME"
if [[ ! -d $MINE || ! -w $MINE ]]; then
    [[ $CHECK -eq 1 ]] && echo "readonly $MINE"
    exit 0
fi

if [[ ! -f $SCHEME ]]; then
    [[ $CHECK -eq 1 ]] && echo noscheme
    exit 0
fi

if [[ $CHECK -eq 1 ]]; then
    echo "ok $THEME"
    exit 0
fi

# already painted, and only the unpainted were asked for
if [[ $MISSING -eq 1 && -s "$MINE/theme.conf" ]]; then
    exit 0
fi

# the wallpaper the shell is on. the theme blurs it itself (backgroundSharp),
# the way the lock screen does, so nothing here needs imagemagick
WALL=""
if [[ -r "$STATE/wallpaper/path.txt" ]]; then
    WALL=$(< "$STATE/wallpaper/path.txt")
elif command -v qs >/dev/null; then
    WALL=$(qs -c caelestia ipc call wallpaper get 2>/dev/null | tr -d '\r' || true)
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# the shell's M3 tokens, under the names the greeter's Theme.qml reads
python3 -I - "$SCHEME" "$WALL" > "$TMP" <<'PY'
import json, sys

scheme = json.load(open(sys.argv[1], encoding="utf-8"))
wall = sys.argv[2] if len(sys.argv) > 2 else ""
c = scheme.get("colours", {})
light = scheme.get("mode", "dark") == "light"

def h(key, fallback="000000"):
    return "#" + c.get(key, fallback)

keys = {
    "isLight": "true" if light else "false",
    "accent": h("primary"),
    "accentHover": h("primaryFixed" if not light else "primaryFixedDim"),
    "fgAccent": h("onPrimary"),
    "accentMuted": h("secondary"),
    "clockHour": h("primaryFixed"),
    "accentContainer": h("primaryContainer"),
    "fgAccentContainer": h("onPrimaryContainer"),
    "bgOpaque": h("surface"),
    "bgHigh": h("surfaceBright"),
    "text": h("onSurface"),
    "subtext": h("onSurfaceVariant"),
    "subtextDim": h("outline"),
    "outline": h("outlineVariant"),
    "outlineStrong": h("onSurfaceVariant"),
    "error": h("error"),
    "fgError": h("onError"),
    "errorHover": h("onErrorContainer"),
    "success": h("success", "b5ccba").lower(),
    "fgSuccess": h("onSuccess", "213528"),
    "warning": h("tertiary"),
    "scrim": h("scrim"),
}

print("[General]")
print("# written by sync-sddm.sh from the shell's scheme.json. edits are overwritten.")
for k, v in keys.items():
    print(f"{k}={v}")
if wall:
    print("backgroundSharp=true")
PY

install -m644 "$TMP" "$MINE/theme.conf"

if [[ -n $WALL && -r $WALL ]]; then
    # the greeter wants a jpeg called background.jpg; a png or webp copied
    # under that name still decodes, Qt goes by content rather than suffix
    install -m644 "$WALL" "$MINE/background.jpg"
fi

echo "sync-sddm: painted $MINE from $(basename "$SCHEME")"
