#!/usr/bin/env bash
#
# install-deps.sh — installs build and runtime dependencies for cykler-caelestia
#
# Usage:
#   ./install-deps.sh                    # everything, asking before each step
#   ./install-deps.sh --repo-only        # skip AUR packages
#   ./install-deps.sh --yes              # don't ask for confirmation (for scripting/CI)
#   ./install-deps.sh --list-features    # the optional feature groups, one per line
#   ./install-deps.sh --features a,b     # only these optional groups (empty for none)
#
# Packages come in two kinds. The required ones are not a choice: the plugin
# links libqalculate, libpipewire, aubio, taglib and cava at build time, the
# shell will not start without quickshell or its icon font, and nothing builds
# without cmake. Those are installed, not offered. Everything else belongs to a
# feature that the shell does without, and those are the groups below.


set -euo pipefail

REPO_ONLY=false
ASSUME_YES=false
# unset means every group; set (even to empty) means exactly what was asked for
FEATURES_SET=false
WANTED=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-only) REPO_ONLY=true; shift ;;
        --yes|-y) ASSUME_YES=true; shift ;;
        --features) WANTED="${2-}"; FEATURES_SET=true; shift 2 ;;
        --features=*) WANTED="${1#*=}"; FEATURES_SET=true; shift ;;
        --list-features) LIST_FEATURES=true; shift ;;
        *) shift ;;
    esac
done
LIST_FEATURES="${LIST_FEATURES:-false}"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)


# --- Required: not offered, because nothing works without them ---------------
#
# build: nothing compiles without these
# qt: the toolkit the whole shell is
# plugin: pkg_check_modules(... REQUIRED) in plugin/CMakeLists.txt, so the build
#   fails outright if any of them is missing
REQ_REPO=(
    git cmake ninja qt6-shadertools python
    qt6-base qt6-declarative qt6-imageformats qt6-multimedia
    libqalculate libpipewire aubio taglib
)

# quickshell is what the shell runs on, m3shapes is a QML module it imports,
# cava is linked by the plugin, the symbols font draws every icon in the shell,
# and the cli is the `caelestia` command the installer starts the shell with
REQ_AUR=(
    aur/quickshell-git
    qt6-m3shapes-git
    libcava
    ttf-material-symbols-variable
    caelestia-cli
)


# --- Optional: one line per feature the shell can do without ------------------
#
# id|label|summary|repo packages|aur packages
# Keep in step with the installer window, which builds its switches from
# --list-features and hands the chosen ids back on --features.
FEATURES=(
    "screenshots|Screenshots|The area picker, annotating a shot and copying it|grim slurp wl-clipboard satty|"
    "ocr|Screen OCR|Reads the text out of any part of the screen|tesseract|"
    "picker|Colour picker|Picks a colour from anywhere on screen|hyprpicker|"
    "brightness|Brightness|The backlight, and external monitors over DDC|brightnessctl ddcutil|"
    "sensors|Sensors & power|Temperatures, fan readings and power profiles|lm_sensors power-profiles-daemon|"
    "network|Network|The network widget, its list and its controls|networkmanager|"
    "web|Weather & tiles|Fetches the weather and the desktop tiles|curl jq|"
    "calendar|Calendar events|Marks the days with GNOME Calendar events on the dashboard|gnome-calendar evolution-data-server python-gobject|"
    "desktop|Desktop links|Opening links, and notifications from scripts|xdg-utils libnotify|"
    "shells|Script shells|The shells the bundled scripts are written in|fish bash|"
    "fonts|Extra fonts|Rubik and Cascadia Code Nerd Font|  |ttf-rubik-vf ttf-cascadia-code-nerd"
    "updates|System updater|Checks pending Arch/AUR updates and creates pre-update Btrfs snapshots|pacman-contrib snapper|"
)

feature_field() {
    # -- feature_field <line> <1-indexed field>
    printf '%s' "$1" | cut -d'|' -f"$2"
}

if [[ "$LIST_FEATURES" == true ]]; then
    for f in "${FEATURES[@]}"; do
        id=$(feature_field "$f" 1)
        label=$(feature_field "$f" 2)
        summary=$(feature_field "$f" 3)
        pkgs="$(feature_field "$f" 4) $(feature_field "$f" 5)"
        printf '%s\t%s\t%s\t%s\n' "$id" "$label" "$summary" "$(echo $pkgs)"
    done
    exit 0
fi

feature_wanted() {
    # -- feature_wanted <id>; every group unless --features said otherwise
    [[ "$FEATURES_SET" == false ]] && return 0
    local want
    IFS=',' read -ra want <<< "$WANTED"
    local w
    for w in "${want[@]}"; do
        [[ "$w" == "$1" ]] && return 0
    done
    return 1
}

REPO_PKGS=("${REQ_REPO[@]}")
AUR_PKGS=("${REQ_AUR[@]}")
PICKED=()
for f in "${FEATURES[@]}"; do
    id=$(feature_field "$f" 1)
    feature_wanted "$id" || continue
    PICKED+=("$(feature_field "$f" 2)")
    # unquoted on purpose: these are space separated lists, not single words
    for p in $(feature_field "$f" 4); do REPO_PKGS+=("$p"); done
    for p in $(feature_field "$f" 5); do AUR_PKGS+=("$p"); done
done

confirm() {
    # -- confirm "prompt text"
    local prompt="$1"
    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi
    read -rp "$prompt [Y/n] " reply
    [[ ! "$reply" =~ ^[Nn]$ ]]
}

echo "==> Required, from the official repos. The shell cannot build or run"
echo "    without these, so they are not optional:"
printf '    %s\n' "${REQ_REPO[@]}"
if (( ${#PICKED[@]} )); then
    echo
    echo "==> Also, for the features you asked for: ${PICKED[*]}"
fi
echo
# -Syu, not -S. Arch does not support installing into a half-updated system:
# pulling one package from a newer repo than the rest gives you errors like
# "installing libpipewire breaks dependency 'libpipewire=<older>' required by
# pipewire", because the rest of that stack is still pinned to the old version.
# pacman lists everything it is about to touch and asks again before it does.
echo "==> Arch cannot install into a half-updated system, so this brings the"
echo "    system up to date first. pacman will list what that means and ask."
echo
if confirm "Update the system and install these?"; then
    sudo pacman -Syu --needed "${REPO_PKGS[@]}"
else
    echo "==> Skipped repo packages. You'll need to install these manually:"
    printf '    %s\n' "${REPO_PKGS[@]}"
fi

if [[ "$REPO_ONLY" == true ]]; then
    echo "==> --repo-only set, skipping AUR packages."
    echo "You'll need to install manually: ${AUR_PKGS[*]}"
    exit 0
fi

# --- Find or offer to install an AUR helper ---
AUR_HELPER=""
for helper in yay paru; do
    if command -v "$helper" >/dev/null 2>&1; then
        AUR_HELPER="$helper"
        break
    fi
done

if [[ -z "$AUR_HELPER" ]]; then
    echo
    echo "==> No AUR helper (yay/paru) found. One is needed to reach the AUR,"
    echo "    and the AUR is where quickshell and the icon font come from, so"
    echo "    without it the shell has nothing to run on."
    if confirm "Install yay now (clones and builds it with makepkg)?"; then
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
        (cd "$tmpdir/yay" && makepkg -si)
        rm -rf "$tmpdir"
        AUR_HELPER="yay"
    else
        echo "==> Skipping AUR packages. The shell will NOT run until these are"
        echo "    installed by hand: ${AUR_PKGS[*]}"
        exit 0
    fi
fi

echo
echo "==> Required, from the AUR using $AUR_HELPER. quickshell is what the shell"
echo "    runs on and the symbols font draws every icon in it, so these are not"
echo "    optional either:"
printf '    %s\n' "${REQ_AUR[@]}"
echo
if confirm "Install the required AUR packages?"; then
    "$AUR_HELPER" -S --needed "${AUR_PKGS[@]}"
else
    echo "==> Skipped AUR packages. You'll need to install these manually:"
    printf '    %s\n' "${AUR_PKGS[@]}"
fi

# --- Check that libcava still loads ------------------------------------------
# --needed leaves an installed libcava alone, and pacman only knows the package
# it depends on, not the sonames inside it: a library taking a soname bump (sndio
# 1.11 dropped libsndio.so.7) leaves the installed libcava unloadable and pacman
# says nothing. The shell links it, so catching that here is the difference
# between a working install and one that will not start. See scripts/deps-check.sh.
if [[ -f $SCRIPT_DIR/scripts/deps-check.sh ]]; then
    # shellcheck source=scripts/deps-check.sh
    source "$SCRIPT_DIR/scripts/deps-check.sh"
    if caelestia_libcava_stale; then
        echo
        echo "==> The installed libcava is out of date: it asks for libraries this"
        echo "    system no longer has:"
        caelestia_libcava_missing | sed 's/^/        /'
        echo
        echo "    Something it links changed soname after libcava was built (sndio"
        echo "    1.11 dropping libsndio.so.7 is the usual one). Pacman sees the"
        echo "    dependency as satisfied, and the shell will not start until it is"
        echo "    rebuilt against what is installed now."
        if confirm "Rebuild libcava now?"; then
            caelestia_rebuild_libcava ||
                echo "==> Rebuild did not finish. Run 'yay -S --rebuild --answerclean All libcava' by hand."
        else
            echo "==> Skipped. Before starting the shell, run:"
            echo "    yay -S --rebuild --answerclean All libcava"
        fi
    fi
fi

echo
echo "==> Done."
echo "Next: clone cykler-caelestia and run the cmake build steps from the README."
