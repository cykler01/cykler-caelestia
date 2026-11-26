#!/usr/bin/env bash
#
# install.sh — full first-time install of cykler-caelestia (Arch Linux)
#
# Usage:
#   ./install.sh                        # install dependencies, then build and install
#   ./install.sh --install-deps false   # skip dependencies (already installed)
#   ./install.sh --repo-only            # pass through: skip AUR packages
#   ./install.sh --yes                  # don't ask for confirmation (for scripting/CI)
#   ./install.sh --gui                  # do all of this from a window
#   ./install.sh --terminal             # stay here, even where a window would open
#   ./install.sh --modules 'plugin;shell'  # build only these (default: extras;plugin;shell)
#   ./install.sh --with login-screen    # also install an add-on (repeatable, or comma separated)
#   ./install.sh --with all             # every add-on
#   ./install.sh --without login-screen # drop one again
#   ./install.sh --list-addons          # what the add-ons are, one per line
#   ./install.sh --features ocr,fonts   # only these optional dependency groups
#   ./install.sh --features ''          # required dependencies only
#   ./install.sh --list-features        # what the groups are, one per line
#
# The shell installs into its own prefix. Add-ons are the things that write
# somewhere else - another package's theme directory, /etc, your home - so none
# of them happen unless they are asked for by name.
#
# Run it from a checkout of the repo, or from anywhere to clone it first.

set -euo pipefail

REPO_URL="https://github.com/cykler01/cykler-caelestia.git"

INSTALL_DEPS=true
REPO_ONLY=false
# unset leaves install-deps.sh to its own default, which is every group
FEATURES_SET=false
FEATURES=""
ASSUME_YES=false
MODULES=""

# --- Add-ons ---
# One entry per optional piece. Keep the functions below in step: --list-addons
# prints from them and the installer window builds its switches from that, so a
# new add-on needs no second list anywhere. Not the same thing as the "extras"
# build module, which is part of the shell itself.
ADDONS=(login-screen)

addon_label() {
    case "$1" in
        login-screen) echo "SDDM login screen" ;;
        *) echo "$1" ;;
    esac
}

addon_summary() {
    case "$1" in
        login-screen) echo "The SDDM theme, in your colours, from your next login" ;;
        *) echo "" ;;
    esac
}

# what it writes that the shell's own install would not
addon_paths() {
    case "$1" in
        login-screen) echo "/usr/share/sddm/themes/cykler-caelestia, /etc/sddm.conf.d, /etc/systemd/system/caelestia-sddm-net.{service,timer}" ;;
        *) echo "" ;;
    esac
}

addon_run() {
    case "$1" in
        login-screen)
            echo "==> Installing the sddm theme"
            sudo "$SRC/sddm/install-theme.sh" --current
            # paint it in this account's colours straight away, rather than leaving
            # the greeter on the shipped default until the next wallpaper change
            "$SRC/sddm/sync-sddm.sh" || true
            ;;
        *)
            echo "No such add-on: $1" >&2
            return 1
            ;;
    esac
}

addon_known() {
    local e
    for e in "${ADDONS[@]}"; do
        [[ $e == "$1" ]] && return 0
    done
    return 1
}

# nothing is on until it is named
WANTED=()

addon_wanted() {
    local e
    for e in "${WANTED[@]+"${WANTED[@]}"}"; do
        [[ $e == "$1" ]] && return 0
    done
    return 1
}

addon_add() {
    local name
    for name in ${1//,/ }; do
        if [[ $name == all ]]; then
            WANTED=("${ADDONS[@]}")
            continue
        fi
        addon_known "$name" || { echo "Unknown add-on: $name (try --list-addons)" >&2; exit 2; }
        addon_wanted "$name" || WANTED+=("$name")
    done
}

addon_drop() {
    local name keep e
    for name in ${1//,/ }; do
        if [[ $name == all ]]; then
            WANTED=()
            continue
        fi
        keep=()
        for e in "${WANTED[@]+"${WANTED[@]}"}"; do
            [[ $e == "$name" ]] || keep+=("$e")
        done
        WANTED=("${keep[@]+"${keep[@]}"}")
    done
}
# "" lets the check below pick the window or the terminal
WITH_GUI=""
# everything but --gui/--terminal, handed to the window so it starts where you left off
GUI_ARGS=()
for a in "$@"; do
    [[ $a == --gui || $a == --terminal ]] || GUI_ARGS+=("$a")
done

# the window follows these; in a terminal they are just comments on stdout
phase() {
    [[ ${CYKLER_INSTALLER:-0} == 1 ]] && printf '@@cykler:phase %s\n' "$1"
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-deps)
            [[ $# -ge 2 ]] || { echo "--install-deps needs a value (true or false)" >&2; exit 2; }
            case "$2" in
                true) INSTALL_DEPS=true ;;
                false) INSTALL_DEPS=false ;;
                *) echo "--install-deps must be 'true' or 'false', got '$2'" >&2; exit 2 ;;
            esac
            shift 2
            ;;
        --install-deps=*)
            set -- "--install-deps" "${1#*=}" "${@:2}"
            ;;
        --repo-only) REPO_ONLY=true; shift ;;
        --features)
            [[ $# -ge 2 ]] || { echo "--features needs a value, e.g. 'ocr,fonts' (try --list-features)" >&2; exit 2; }
            FEATURES="$2"; FEATURES_SET=true; shift 2 ;;
        --features=*) FEATURES="${1#*=}"; FEATURES_SET=true; shift ;;
        --list-features) ./install-deps.sh --list-features; exit 0 ;;
        --modules)
            [[ $# -ge 2 ]] || { echo "--modules needs a value, e.g. 'plugin;shell'" >&2; exit 2; }
            MODULES="$2"; shift 2 ;;
        --modules=*) MODULES="${1#*=}"; shift ;;
        --with)
            [[ $# -ge 2 ]] || { echo "--with needs an add-on's name (try --list-addons)" >&2; exit 2; }
            addon_add "$2"; shift 2 ;;
        --with=*) addon_add "${1#*=}"; shift ;;
        --without)
            [[ $# -ge 2 ]] || { echo "--without needs an add-on's name" >&2; exit 2; }
            addon_drop "$2"; shift 2 ;;
        --without=*) addon_drop "${1#*=}"; shift ;;
        # the names these had before add-ons were a list
        --login-screen) addon_add login-screen; shift ;;
        --no-login-screen) addon_drop login-screen; shift ;;
        --list-addons)
            for e in "${ADDONS[@]}"; do
                printf '%s\t%s\t%s\t%s\n' "$e" "$(addon_label "$e")" "$(addon_summary "$e")" "$(addon_paths "$e")"
            done
            exit 0
            ;;
        --gui) WITH_GUI=1; shift ;;
        --terminal) WITH_GUI=0; shift ;;
        --yes|-y) ASSUME_YES=true; shift ;;
        -h|--help)
            # the whole header comment, however long it grows
            awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

confirm() {
    $ASSUME_YES && return 0
    local reply
    read -rp "$1 [y/N] " reply
    [[ $reply == [yY]* ]]
}

# --- The window ---
# installer.qml runs this same script through installer/runner.py, its switches
# as flags, so the window asks exactly what the terminal below would ask

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Never from inside the window. runner.py runs this on a pty, so -t 1 is true
# there and the check below would happily open a second installer on top of the
# one already driving it -- and then exec away from the runner watching us
if [[ ${CYKLER_INSTALLER:-0} == 1 ]]; then
    WITH_GUI=0
fi

if [[ -z "$WITH_GUI" ]]; then
    WITH_GUI=0
    # a window is only worth offering where one can actually open, and where the
    # shell's own runtime is already installed to draw it
    if [[ -n "${WAYLAND_DISPLAY:-}" && -t 1 && -f "$SRC/installer.qml" ]] && command -v qs >/dev/null; then
        WITH_GUI=1
    fi
fi

if [[ $WITH_GUI -eq 1 ]]; then
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        echo "No Wayland session here, so the install carries on in the terminal."
    elif ! command -v qs >/dev/null; then
        echo "quickshell is not installed yet, so the install carries on in the terminal."
    else
        echo "Opening the installer window (./install.sh --terminal stays here)."
        CYKLER_INSTALL_ARGS="${GUI_ARGS[*]}" exec qs -p "$SRC/installer.qml"
    fi
fi

# --- Pre-Download ---
command -v pacman >/dev/null || { echo "This script only supports Arch Linux." >&2; exit 1; }
[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root (sudo is used where needed)." >&2; exit 1; }

# This fork provides the same package, so the AUR version has to go first
for pkg in caelestia-shell caelestia-shell-git; do
    if pacman -Qq "$pkg" &>/dev/null; then
        confirm "$pkg conflicts with this fork. Remove it?" || { echo "Aborting."; exit 1; }
        sudo pacman -Rns "$pkg"
    fi
done

# --- Source ---
if [[ ! -f CMakeLists.txt || ! -f install-deps.sh ]]; then
    command -v git >/dev/null || sudo pacman -S --needed --noconfirm git
    git clone "$REPO_URL"
    cd "$(basename "$REPO_URL" .git)"
fi

# --- Dependencies ---
phase deps
if $INSTALL_DEPS; then
    deps_args=()
    $ASSUME_YES && deps_args+=(--yes)
    $REPO_ONLY && deps_args+=(--repo-only)
    $FEATURES_SET && deps_args+=(--features "$FEATURES")
    ./install-deps.sh "${deps_args[@]}"
else
    echo "Skipping dependencies (--install-deps false)."
fi

# --- Configure ---
# CMakeLists.txt reads the version from `git describe --tags`, which fails
# on clones without tags, so fall back to a fixed one.
phase configure
cmake_args=(-B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/)
[[ -n "$MODULES" ]] && cmake_args+=(-DENABLE_MODULES="$MODULES")
git describe --tags --abbrev=0 &>/dev/null || cmake_args+=(-DVERSION=0.0.0-fork)
cmake "${cmake_args[@]}"

# --- Build and install ---
phase build
cmake --build build
phase install
sudo cmake --install build

# --- Add-ons ---
# after the shell, so a half-finished build never leaves the login screen
# pointing at a theme that is not there yet
for addon in "${WANTED[@]+"${WANTED[@]}"}"; do
    phase "addon:$addon"
    addon_run "$addon"
done

# --- Post-install checks ---
pacman -Qq quickshell-git &>/dev/null || echo "WARNING: quickshell-git is not installed; the stable quickshell can leave the shell blank."

# The services plugin is the first thing shell.qml loads, so a library it links
# going missing takes the whole config down with it, at startup, before anything
# can report why. libcava is the usual one - AUR-only, and stale whenever a
# library it links takes a soname bump (sndio 1.11 dropped libsndio.so.7) since
# pacman tracks the package, not the soname. Only install-deps.sh can rebuild it;
# this catches the case where dependencies were skipped. See scripts/deps-check.sh.
plugin=/usr/lib/qt6/qml/Caelestia/Services/libcaelestia-servicesplugin.so
if [[ -e $plugin ]]; then
    missing=$(LC_ALL=C ldd "$plugin" 2>/dev/null | awk '$2 == "=>" && $3 == "not" && $4 == "found" { print $1 }' || true)
    if [[ -n $missing ]]; then
        echo "WARNING: the shell's services plugin cannot load; it asks for:"
        printf '%s\n' "$missing" | sed 's/^/         /'
        echo "         libcava is the usual cause, an AUR package left behind by a soname bump."
        echo "         The shell will not start until it is rebuilt:"
        echo "           yay -S --rebuild --answerclean All libcava"
    fi
fi

# polkit allows one authentication agent per session, so whichever registers first is the one that
# gets asked. With another agent autostarting, the shell's own prompt - the one that drops out of
# the notch - never gets a look in, and it fails quietly: the password dialog still appears, it is
# just somebody else's. Worth saying so at install time rather than leaving it to be noticed.
AGENT_NAMES='polkit-gnome-authentication-agent-1|hyprpolkitagent|polkit-kde-authentication-agent-1|polkit-mate-authentication-agent-1|lxpolkit|xfce-polkit'

check_polkit_agent() {
    local running
    running=$(pgrep -af "$AGENT_NAMES" 2>/dev/null | grep -vE 'pgrep|install\.sh' || true)
    local -a hits=()

    # Where it is likely started from. Autostart entries can be overridden per user; a line in a
    # compositor config has to be edited where it is.
    local f
    for f in /etc/xdg/autostart/*.desktop "$HOME"/.config/autostart/*.desktop; do
        [[ -f $f ]] || continue
        grep -qE "$AGENT_NAMES" "$f" && hits+=("$f")
    done
    # Only lines that actually launch one: a window rule naming the same binary is not a culprit
    while IFS= read -r line; do
        [[ -n $line ]] && hits+=("$line")
    done < <(grep -rnE "exec.*($AGENT_NAMES)" "$HOME/.config/hypr" 2>/dev/null | cut -d: -f1,2 || true)

    [[ -z $running && ${#hits[@]} -eq 0 ]] && return 0

    echo
    echo "NOTE: another polkit authentication agent is set up on this session."
    [[ -n $running ]] && echo "      running: $running"
    for f in "${hits[@]}"; do
        echo "      started from: $f"
    done
    echo "      Only one agent can hold a session, so the shell's own password prompt will not"
    echo "      appear until that one is stopped. Disable it there, then log back in."
}

check_polkit_agent

echo
echo "Done. Start the shell with: caelestia shell -d"
