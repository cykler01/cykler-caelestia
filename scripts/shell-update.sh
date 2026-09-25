#!/usr/bin/env bash
#
# shell-update.sh - backend for the shell's Update page. Prints machine-readable lines.
#
#   shell-update.sh check   REPO BRANCH
#       Fetches, then prints HEAD:, BRANCH:, DIRTY:, BEHIND: and up to 15 LOG: lines.
#   shell-update.sh install REPO BRANCH [stash]
#       Pulls BRANCH from origin (optionally stashing local changes first and restoring them
#       afterwards), rebuilds, and installs with pkexec. Prints STEP:, WARN:, ERROR: and DONE.
#
# The shell restarts itself after DONE; this script never does.

set -uo pipefail

mode="${1:-}"
repo="${2:-}"
branch="${3:-main}"
stash="${4:-no}"

if [[ -z "$mode" || -z "$repo" || ! -d "$repo/.git" ]]; then
    echo "ERROR:not a git checkout: $repo"
    exit 1
fi
cd "$repo" || exit 1

dirty() { [[ -n "$(git status --porcelain)" ]]; }

case "$mode" in
check)
    if ! timeout 25 git fetch origin "$branch" >/dev/null 2>&1; then
        echo "ERROR:could not reach origin (check your connection)"
        exit 1
    fi
    echo "HEAD:$(git rev-parse --short HEAD)"
    echo "BRANCH:$(git rev-parse --abbrev-ref HEAD)"
    if dirty; then echo "DIRTY:1"; else echo "DIRTY:0"; fi
    echo "BEHIND:$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)"
    git log --format='LOG:%h %s' -15 "HEAD..origin/$branch" 2>/dev/null
    ;;
install)
    stashed=0
    restore() {
        if [[ "$stashed" == 1 ]]; then
            if git stash pop >/dev/null 2>&1; then
                echo "STEP:restored your local changes"
            else
                echo "WARN:could not restore your stashed changes automatically; they are in 'git stash list'"
            fi
            stashed=0
        fi
    }

    if dirty; then
        if [[ "$stash" != "stash" ]]; then
            echo "ERROR:you have uncommitted changes"
            exit 2
        fi
        echo "STEP:stashing local changes"
        if ! git stash push -u -m "shell-update" >/dev/null 2>&1; then
            echo "ERROR:could not stash local changes"
            exit 2
        fi
        stashed=1
    fi

    echo "STEP:pulling $branch"
    if ! git pull --no-rebase --no-edit origin "$branch" 2>&1 | sed 's/^/LOG:/'; then
        git merge --abort >/dev/null 2>&1
        echo "ERROR:pull failed (merge conflict or network); nothing was installed"
        restore
        exit 3
    fi
    if [[ "${PIPESTATUS[0]}" != 0 ]]; then
        git merge --abort >/dev/null 2>&1
        echo "ERROR:pull failed (merge conflict or network); nothing was installed"
        restore
        exit 3
    fi

    echo "STEP:building"
    if [[ ! -d build ]]; then
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ >/dev/null 2>&1 || { echo "ERROR:cmake configure failed"; restore; exit 4; }
    fi
    if ! cmake --build build 2>&1 | tail -n 3 | sed 's/^/LOG:/'; then
        echo "ERROR:build failed"
        restore
        exit 4
    fi
    if [[ "${PIPESTATUS[0]}" != 0 ]]; then
        echo "ERROR:build failed"
        restore
        exit 4
    fi

    echo "STEP:installing (waiting for your password)"
    if ! pkexec cmake --install "$repo/build" >/dev/null 2>&1; then
        echo "ERROR:install failed or was cancelled"
        restore
        exit 5
    fi

    restore
    echo "DONE"
    ;;
*)
    echo "ERROR:unknown mode '$mode'"
    exit 1
    ;;
esac
