#!/usr/bin/env bash
#
# update.sh — updates cykler-caelestia, optionally pulling in upstream changes first
#
# Usage:
#   ./update.sh                 # pull the fork's own commits, then rebuild/install
#   ./update.sh --upstream      # also merge in upstream caelestia-dots/shell
#   ./update.sh --yes           # don't ask for confirmation (for scripting)


set -euo pipefail

UPSTREAM_URL="https://github.com/caelestia-dots/shell.git"
UPSTREAM_REMOTE="upstream"
SKIP_UPSTREAM=true
ASSUME_YES=false

for arg in "$@"; do
    case "$arg" in
        --upstream) SKIP_UPSTREAM=false ;;
        --yes|-y) ASSUME_YES=true ;;
    esac
done

confirm() {
    local prompt="$1"
    if [[ "$ASSUME_YES" == true ]]; then
        return 0
    fi
    read -rp "$prompt [Y/n] " reply
    [[ ! "$reply" =~ ^[Nn]$ ]]
}

# --- Sanity check: must be run from inside the repo ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository. Run this from inside your cykler-caelestia clone." >&2
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# --- Refuse to run with uncommitted local changes ---
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: you have uncommitted local changes. Commit, stash, or discard them first:" >&2
    git status --short >&2
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "==> On branch '$CURRENT_BRANCH' in $REPO_ROOT"

# --- Pull fork's own commits ---
echo "==> Fetching origin..."
git fetch origin
BEHIND_ORIGIN=$(git rev-list --count "HEAD..origin/$CURRENT_BRANCH" 2>/dev/null || echo 0)
if [[ "$BEHIND_ORIGIN" -gt 0 ]]; then
    echo "==> $BEHIND_ORIGIN new commit(s) on origin/$CURRENT_BRANCH."
    if confirm "Pull them now?"; then
        git pull --ff-only origin "$CURRENT_BRANCH"
    fi
else
    echo "==> Already up to date with origin/$CURRENT_BRANCH."
fi

# --- Merge upstream ---
if [[ "$SKIP_UPSTREAM" == false ]]; then
    if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
        echo "==> No '$UPSTREAM_REMOTE' remote found."
        if confirm "Add $UPSTREAM_URL as '$UPSTREAM_REMOTE'?"; then
            git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
        else
            echo "==> Skipping upstream merge."
            SKIP_UPSTREAM=true
        fi
    fi
fi

if [[ "$SKIP_UPSTREAM" == false ]]; then
    echo "==> Fetching $UPSTREAM_REMOTE..."
    git fetch "$UPSTREAM_REMOTE"
    BEHIND_UPSTREAM=$(git rev-list --count "HEAD..$UPSTREAM_REMOTE/main" 2>/dev/null || echo 0)
    if [[ "$BEHIND_UPSTREAM" -gt 0 ]]; then
        echo "==> $BEHIND_UPSTREAM new commit(s) on $UPSTREAM_REMOTE/main."
        echo "    Recent upstream changes:"
        git log --oneline "HEAD..$UPSTREAM_REMOTE/main" | head -10 | sed 's/^/      /'
        if confirm "Merge $UPSTREAM_REMOTE/main into $CURRENT_BRANCH now?"; then
            git merge "$UPSTREAM_REMOTE/main" --no-edit
        else
            echo "==> Skipped upstream merge."
        fi
    else
        echo "==> Already up to date with $UPSTREAM_REMOTE/main."
    fi
fi

# --- Rebuild and reinstall ---
if [[ ! -d build ]]; then
    echo "==> No existing build directory; running full configure."
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
fi

echo
if confirm "Rebuild and reinstall now (sudo cmake --install build)?"; then
    cmake --build build
    sudo cmake --install build
    echo "==> Done. Restart the shell to pick up changes: caelestia shell -d"
else
    echo "==> Skipped build/install. Run manually when ready:"build
    echo "    cmake --build build && sudo cmake --install build"
fi