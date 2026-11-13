#!/usr/bin/env bash
#
# find-files.sh — the launcher's ">find" mode.
#
#   find-files.sh LIMIT QUERY ROOT...
#
# Prints up to LIMIT lines of "<mtime>\t<path>", newest first. An empty QUERY lists what has been
# touched lately instead of matching on a name, so ">find" on its own answers "what was I just
# working on".
#
# Ordering is by modification time rather than by how well the name matched, because a search over
# a whole home directory turns up the same name in a dozen places and the one wanted is nearly
# always the recent one. fd does the walking (it honours .gitignore and skips the noise), and one
# stat call covers every hit rather than one per file.

# No pipefail: the walk is deliberately cut short by `head`, and the SIGPIPE that gives fd is the
# intended end of it, not a failure
set -u

limit=${1:?limit}
query=${2-}
shift 2

# Nothing to search
[[ $# -eq 0 ]] && exit 0

command -v fd >/dev/null 2>&1 || {
    echo "ERROR:fd is not installed" >&2
    exit 127
}

args=(
    --type f
    --absolute-path
    --ignore-case
    --follow
    # Caches, build output and version control are never what someone is looking for, and walking
    # them is most of the cost of a search over a home directory
    --exclude .git
    --exclude .cache
    --exclude node_modules
    --exclude .venv
    --exclude __pycache__
    --exclude target
    --exclude .npm
    --exclude .local/share/Trash
    --print0
)

# A ceiling on the walk, so a huge tree cannot make the launcher wait. Not fd's own --max-results,
# which it refuses to combine with a batched command
walk_limit=600

if [[ -z $query ]]; then
    # No name to go on, so "recent" is the whole query
    args+=(--changed-within 14d '.')
else
    args+=("$query")
fi

# NUL separated throughout, so a space or a quote in a name cannot split a path. One stat covers
# every hit rather than one per file
fd "${args[@]}" "$@" 2>/dev/null |
    head -z -n "$walk_limit" |
    xargs -0 -r stat --printf '%Y\t%n\n' -- 2>/dev/null |
    sort -rn |
    head -n "$limit"
