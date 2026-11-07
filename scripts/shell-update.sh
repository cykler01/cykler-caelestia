#!/usr/bin/env bash
#
# shell-update.sh - backend for the shell's Update page. Prints machine-readable lines.
#
#   shell-update.sh check   REPO BRANCH
#       Fetches, then prints HEAD:, BRANCH:, DIRTY:, BEHIND:, CURRENT:, LATEST: and up to 15 LOG: lines.
#       CURRENT: and LATEST: are the commit dates of this checkout and of origin/BRANCH, which the
#       Update page shows as the age of this build and of the newest one available.
#       With local changes it also prints DIRTYFILE: per changed file, STASHSAFE:0|1 for whether
#       they would come back cleanly after the update, and RISKFILE: for each one that would not.
#   shell-update.sh branches REPO
#       Prints the branches available on origin, one BRANCH: line each, for the update page's picker.
#   shell-update.sh install REPO BRANCH [no|stash|overwrite]
#       Pulls BRANCH from origin, rebuilds, and installs with pkexec. Prints STEP:, WARN:, ERROR:
#       and DONE. With local changes present: 'no' refuses, 'stash' puts them back afterwards, and
#       'overwrite' leaves them in the stash so the update wins. Nothing is ever discarded.
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
    echo "CURRENT:$(git log -1 --format=%cI HEAD 2>/dev/null)"
    echo "LATEST:$(git log -1 --format=%cI "origin/$branch" 2>/dev/null)"
    git log --format='LOG:%h %s' -15 "HEAD..origin/$branch" 2>/dev/null

    # Whether the local changes would survive being stashed over the update and restored. Worth
    # knowing before the update runs rather than after it, which is when the old flow found out.
    if dirty; then
        git status --porcelain | sed 's/^...//' | head -40 | sed 's|^|DIRTYFILE:|'

        safe=1

        # Tracked changes, tested exactly: `git stash create` writes a commit object and leaves the
        # working tree alone, and merge-tree does the same three way merge the restore would, in
        # memory. It prints the resulting tree, then the conflicted paths, then a blank line and
        # some prose about them - so the paths are everything between line one and that blank.
        stash_commit=$(git stash create 2>/dev/null)
        if [[ -n "$stash_commit" ]]; then
            if ! merged=$(git merge-tree --write-tree --name-only "origin/$branch" "$stash_commit" 2>/dev/null); then
                safe=0
                printf '%s\n' "$merged" | awk 'NR == 1 { next } /^$/ { exit } { print }' |
                    head -20 | sed 's|^|RISKFILE:|'
            fi
        fi

        # Untracked files are not part of a stash commit, so they are checked separately: one the
        # update also creates is in the way when the stash goes back
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            if git cat-file -e "origin/$branch:$f" 2>/dev/null && ! git cat-file -e "HEAD:$f" 2>/dev/null; then
                safe=0
                echo "RISKFILE:$f"
            fi
        done < <(git ls-files --others --exclude-standard)

        echo "STASHSAFE:$safe"
    fi
    ;;
branches)
    # List the branches on origin, one BRANCH: line each. Ask the remote directly so newly pushed
    # branches show up, and fall back to what the last fetch left behind when it cannot be reached.
    if remotes=$(timeout 25 git ls-remote --heads origin 2>/dev/null) && [[ -n "$remotes" ]]; then
        printf '%s\n' "$remotes" | sed -n 's|.*refs/heads/|BRANCH:|p'
    else
        git branch -r --format='%(refname:short)' 2>/dev/null | sed -n 's|^origin/||p' | grep -vx 'HEAD' | sed 's|^|BRANCH:|' || true
    fi
    ;;
install)
    stashed=0
    # 'overwrite' keeps the changes in the stash instead of putting them back, so the update wins
    # without anything being thrown away
    keep_stashed=0
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
        case "$stash" in
        stash) ;;
        overwrite) keep_stashed=1 ;;
        *)
            echo "ERROR:you have uncommitted changes"
            exit 2
            ;;
        esac
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
    # Checked on every run, not just when build/ is missing. A build directory
    # left over from a plain `cmake -B build` is configured for /usr/local, and
    # reusing it installs a full copy of the shell where nothing loads it, so the
    # update page reports success and the old shell keeps running. See
    # scripts/build-env.sh.
    source "$repo/scripts/build-env.sh"
    if ! configured=$(caelestia_configure_build 2>/dev/null); then
        echo "ERROR:cmake configure failed"
        restore
        exit 4
    fi
    if [[ -n $configured ]]; then
        echo "LOG:$configured"
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

    if [[ "$keep_stashed" == 1 && "$stashed" == 1 ]]; then
        echo "WARN:your local changes were not put back; they are in 'git stash list' as 'shell-update'"
        stashed=0
    else
        restore
    fi
    echo "DONE"
    ;;
*)
    echo "ERROR:unknown mode '$mode'"
    exit 1
    ;;
esac
