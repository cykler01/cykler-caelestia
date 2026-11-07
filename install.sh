#!/usr/bin/env bash
#
# install.sh — full first-time install of cykler-caelestia (Arch Linux)
#
# Usage:
#   ./install.sh                        # install dependencies, then build and install
#   ./install.sh --install-deps false   # skip dependencies (already installed)
#   ./install.sh --repo-only            # pass through: skip AUR packages
#   ./install.sh --yes                  # don't ask for confirmation (for scripting/CI)
#
# Run it from a checkout of the repo, or from anywhere to clone it first.

set -euo pipefail

REPO_URL="https://github.com/cykler01/cykler-caelestia.git"

INSTALL_DEPS=true
REPO_ONLY=false
ASSUME_YES=false

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
        --yes|-y) ASSUME_YES=true; shift ;;
        -h|--help)
            sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
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
if $INSTALL_DEPS; then
    deps_args=()
    $ASSUME_YES && deps_args+=(--yes)
    $REPO_ONLY && deps_args+=(--repo-only)
    ./install-deps.sh "${deps_args[@]}"
else
    echo "Skipping dependencies (--install-deps false)."
fi

# --- Configure ---
# CMakeLists.txt reads the version from `git describe --tags`, which fails
# on clones without tags, so fall back to a fixed one.
cmake_args=(-B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/)
git describe --tags --abbrev=0 &>/dev/null || cmake_args+=(-DVERSION=0.0.0-fork)
cmake "${cmake_args[@]}"

# --- Build and install ---
cmake --build build
sudo cmake --install build

# --- Post-install checks ---
pacman -Qq quickshell-git &>/dev/null || echo "WARNING: quickshell-git is not installed; the stable quickshell can leave the shell blank."

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
