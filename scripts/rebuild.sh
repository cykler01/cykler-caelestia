#!/usr/bin/env bash
#
# rebuild.sh — rebuild this checkout and install it over the running shell.
#
# Usage:
#   caelestia rebuild                 rebuild, install, restart the shell
#   caelestia rebuild --pull          fast-forward from origin first
#   caelestia rebuild --upstream      also merge upstream/main (implies --pull)
#   caelestia rebuild --clean         discard build/ and configure from scratch
#   caelestia rebuild --no-restart    install, but leave the running shell alone
#   caelestia rebuild --check         report what is installed and exit
#   caelestia rebuild -y, --yes       don't ask anything
#
# Reached as `caelestia rebuild` through the wrapper in ~/.local/bin/caelestia;
# runs the same either way.

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

# shellcheck source=scripts/build-env.sh
source "$REPO_ROOT/scripts/build-env.sh"
# shellcheck source=scripts/deps-check.sh
source "$REPO_ROOT/scripts/deps-check.sh"

PULL=false
UPSTREAM=false
CLEAN=false
RESTART=true
CHECK=false
ASSUME_YES=false

UPSTREAM_URL="https://github.com/caelestia-dots/shell.git"
UPSTREAM_REMOTE=upstream

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pull) PULL=true ;;
        --upstream) UPSTREAM=true; PULL=true ;;
        --clean) CLEAN=true ;;
        --no-restart) RESTART=false ;;
        --check) CHECK=true ;;
        -y|--yes) ASSUME_YES=true ;;
        -h|--help) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "rebuild: unknown option '$1' (try --help)" >&2; exit 2 ;;
    esac
    shift
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
    $ASSUME_YES && return 0
    local reply
    read -rp "$1 [Y/n] " reply </dev/tty || return 1
    [[ ! $reply =~ ^[Nn] ]]
}

QSCONF=$(caelestia_installed_qsconfdir)

# The real CLI, not this script's wrapper, so restarting cannot recurse.
real_cli() {
    local c
    for c in /usr/bin/caelestia /usr/local/bin/caelestia; do
        [[ -x $c ]] && { echo "$c"; return 0; }
    done
    return 1
}

shell_running() {
    pgrep -f 'qs -c caelestia' >/dev/null 2>&1
}

# Whether what is installed matches this checkout, via a file that ships verbatim.
installed_matches() {
    [[ -f "$QSCONF/$CAELESTIA_SENTINEL" ]] || return 1
    cmp -s "$CAELESTIA_SENTINEL" "$QSCONF/$CAELESTIA_SENTINEL"
}

report() {
    bold "checkout"
    note "path      $REPO_ROOT"
    note "branch    $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(not a git checkout)')"
    note "commit    $(git log -1 --format='%h %s' 2>/dev/null || echo '-')"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        note "state     uncommitted changes present"
    else
        note "state     clean"
    fi

    echo
    bold "build"
    local cached
    cached=$(caelestia_cached_prefix)
    if [[ -z $cached ]]; then
        note "prefix    (not configured yet)"
    elif [[ $cached != "$CAELESTIA_PREFIX" ]]; then
        note "prefix    $cached  <-- wrong, nothing loads this; rebuild will repoint it"
    else
        note "prefix    $cached"
    fi

    echo
    bold "installed"
    if [[ ! -d $QSCONF ]]; then
        note "$QSCONF does not exist; the shell has never been installed"
    elif installed_matches; then
        note "$QSCONF matches this checkout"
    else
        note "$QSCONF differs from this checkout"
        if [[ -f "$QSCONF/$CAELESTIA_SENTINEL" ]]; then
            note "  ($CAELESTIA_SENTINEL installed $(date -r "$QSCONF/$CAELESTIA_SENTINEL" '+%Y-%m-%d %H:%M'))"
        else
            note "  ($CAELESTIA_SENTINEL is not installed at all)"
        fi
    fi
    if shell_running; then
        note "shell is running"
    else
        note "shell is not running"
    fi

    local stray
    stray=$(caelestia_stray_dirs)
    if [[ -n $stray ]]; then
        echo
        bold "stray /usr/local install"
        while IFS= read -r d; do note "$d"; done <<< "$stray"
        note "nothing reads these; 'caelestia rebuild' offers to remove them"
    fi
}

if $CHECK; then
    report
    exit 0
fi

# --- git ---
if $PULL; then
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git checkout: $REPO_ROOT"
    [[ -z "$(git status --porcelain)" ]] || die "you have uncommitted changes; commit, stash or discard them first"

    branch=$(git rev-parse --abbrev-ref HEAD)
    step "fetching origin"
    git fetch origin
    behind=$(git rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)
    if [[ $behind -gt 0 ]]; then
        step "$behind new commit(s) on origin/$branch"
        git log --oneline "HEAD..origin/$branch" | head -10 | sed 's/^/    /'
        git pull --ff-only origin "$branch"
    else
        note "already up to date with origin/$branch"
    fi

    if $UPSTREAM; then
        if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
            if confirm "add $UPSTREAM_URL as '$UPSTREAM_REMOTE'?"; then
                git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
            else
                UPSTREAM=false
            fi
        fi
    fi
    if $UPSTREAM; then
        step "fetching $UPSTREAM_REMOTE"
        git fetch "$UPSTREAM_REMOTE"
        behind=$(git rev-list --count "HEAD..$UPSTREAM_REMOTE/main" 2>/dev/null || echo 0)
        if [[ $behind -gt 0 ]]; then
            step "$behind new commit(s) on $UPSTREAM_REMOTE/main"
            git log --oneline "HEAD..$UPSTREAM_REMOTE/main" | head -10 | sed 's/^/    /'
            if confirm "merge $UPSTREAM_REMOTE/main into $branch?"; then
                git merge "$UPSTREAM_REMOTE/main" --no-edit
            fi
        else
            note "already up to date with $UPSTREAM_REMOTE/main"
        fi
    fi
fi

# --- dependencies the build links ---
# The plugin links the AUR libcava. Rebuilding this checkout does not rebuild it,
# and if a library libcava links has changed soname since (sndio 1.11 did) it no
# longer loads - so the build installs and the shell still will not start. See
# scripts/deps-check.sh.
if caelestia_libcava_stale; then
    echo
    warn "libcava is installed but no longer loads: it asks for"
    caelestia_libcava_missing | sed 's/^/    /' >&2
    note "something it links changed soname after it was built; the shell will not start until it is rebuilt"
    if confirm "rebuild libcava now (clean AUR build)?"; then
        caelestia_rebuild_libcava || warn "libcava rebuild did not finish; run 'yay -S --rebuild --answerclean All libcava'"
    fi
fi

# --- configure ---
if $CLEAN; then
    step "discarding build/"
    rm -rf build
fi

configured=$(caelestia_configure_build)
if [[ -n $configured ]]; then
    case "$configured" in
        *repointing*) warn "$configured" ;;
        *) step "$configured" ;;
    esac
else
    note "build already configured for prefix $CAELESTIA_PREFIX"
fi

# --- build ---
step "building"
cmake --build build

# --- install ---
step "installing to $CAELESTIA_PREFIX (sudo)"
sudo cmake --install build

# --- verify ---
if installed_matches; then
    step "verified: $QSCONF matches this checkout"
else
    die "install finished but $QSCONF still differs from this checkout.
    Check the prefix with 'caelestia rebuild --check'."
fi

# --- stray /usr/local tree ---
stray=$(caelestia_stray_dirs)
if [[ -n $stray ]]; then
    echo
    warn "a previous install went to /usr/local, where nothing reads it:"
    while IFS= read -r d; do note "$d"; done <<< "$stray"
    if confirm "remove them?"; then
        # shellcheck disable=SC2046
        sudo rm -rf $(caelestia_stray_dirs | tr '\n' ' ')
        note "removed"
    fi
fi

# --- restart ---
# caelestia-cli 1.1.2 dropped the -r/--restart flag, so restarting there is
# 'shell -k' followed by 'shell -d'. Try -r first so older CLIs still work.
if $RESTART; then
    if cli=$(real_cli); then
        step "restarting the shell"
        if ! "$cli" shell -r -d >/dev/null 2>&1; then
            "$cli" shell -k >/dev/null 2>&1 || warn "the shell was not running"
            # qs refuses to start while the old instance is still shutting down
            for _ in {1..30}; do
                pgrep -f '^qs -c caelestia' >/dev/null 2>&1 || break
                sleep 0.1
            done
            "$cli" shell -d
        fi
    else
        warn "could not find the caelestia CLI; restart the shell yourself"
    fi
else
    note "not restarting; run 'caelestia shell -k && caelestia shell -d' to pick up the new build"
fi

bold "done"
