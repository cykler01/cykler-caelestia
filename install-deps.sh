#!/usr/bin/env bash
#
# install-deps.sh — installs build and runtime dependencies for cykler-caelestia
#
# Usage:
#   ./install-deps.sh              # install everything (repo + AUR), asking before each step
#   ./install-deps.sh --repo-only  # skip AUR packages
#   ./install-deps.sh --yes        # don't ask for confirmation (for scripting/CI)


set -euo pipefail

REPO_ONLY=false
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --repo-only) REPO_ONLY=true ;;
        --yes|-y) ASSUME_YES=true ;;
    esac
done


# --- Packages available in the official Arch repos ---
REPO_PKGS=(
    # -- build deps
    git cmake ninja qt6-shadertools
    # -- runtime deps
    ddcutil brightnessctl
    networkmanager lm_sensors aubio libpipewire libqalculate power-profiles-daemon
    qt6-base qt6-declarative qt6-imageformats
    swappy fish bash grim slurp tesseract wl-clipboard libnotify curl jq xdg-utils
)


# --- Packages that only exist in the AUR ---
AUR_PKGS=(
    caelestia-cli
    aur/quickshell-git
    qt6-m3shapes-git
    libcava
    ttf-material-symbols-variable
    ttf-rubik-vf
    ttf-cascadia-code-nerd
)

confirm() {
    # -- confirm "prompt text"
    local prompt="$1"
    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi
    read -rp "$prompt [Y/n] " reply
    [[ ! "$reply" =~ ^[Nn]$ ]]
}

echo "==> The following packages will be installed from the official repos:"
printf '    %s\n' "${REPO_PKGS[@]}"
echo
if confirm "Proceed with repo package install?"; then
    sudo pacman -S --needed "${REPO_PKGS[@]}"
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
    echo "==> No AUR helper (yay/paru) found."
    if confirm "Install yay now (clones and builds it with makepkg)?"; then
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
        (cd "$tmpdir/yay" && makepkg -si)
        rm -rf "$tmpdir"
        AUR_HELPER="yay"
    else
        echo "==> Skipping AUR packages. Install these manually: ${AUR_PKGS[*]}"
        exit 0
    fi
fi

echo
echo "==> The following packages will be installed from the AUR using $AUR_HELPER:"
printf '    %s\n' "${AUR_PKGS[@]}"
echo
if confirm "Proceed with AUR package install?"; then
    "$AUR_HELPER" -S --needed "${AUR_PKGS[@]}"
else
    echo "==> Skipped AUR packages. You'll need to install these manually:"
    printf '    %s\n' "${AUR_PKGS[@]}"
fi

echo
echo "==> Done."
echo "Next: clone cykler-caelestia and run the cmake build steps from the README."