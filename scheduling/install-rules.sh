#!/usr/bin/env bash
# install-rules.sh [--remove | --status [pid]] — installs the ananicy rule that
# stops the shell being scheduled as a background daemon. needs root for the
# install and for --remove; Nexus runs it through pkexec from the Plugins page,
# and it works by hand under sudo just the same.
#
# --status needs no root and changes nothing. It prints key=value lines for the
# Plugins page to read:
#     service=   the ananicy unit found, or empty where none is installed
#     active=    1 when that unit is running
#     rule=      1 when this rule is installed
#     nice=      the priority the shell is running at right now
#     target=    the priority the rule asks for
#     conflict=  another file in the directory that also names "qs", if any
#
# ananicy only applies a rule to a process the first time it sees it, so a shell
# that is already running keeps whatever nice it started with. This renices the
# running ones too, so the fix lands without a restart.
#
# a no-op where ananicy is not installed: the rule is a file in a directory
# nothing else reads, so there is nothing to undo later if ananicy arrives.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# overridable so the install can be tried somewhere other than /etc
ANANICY_D="${CAELESTIA_ANANICY_D:-/etc/ananicy.d}"
RULE_NAME=99-cykler-caelestia.rules
DEST="$ANANICY_D/$RULE_NAME"
# kept in step with the rule file, which is the thing that actually sets it
TARGET_NICE=-6
REMOVE=0
STATUS=0
STATUS_PID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove) REMOVE=1; shift ;;
        --status) STATUS=1; shift ;;
        [0-9]*) STATUS_PID=$1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# ananicy-cpp and the older python ananicy read the same directory
service=""
for s in ananicy-cpp ananicy; do
    if systemctl list-unit-files "$s.service" &>/dev/null \
        && [[ -n $(systemctl list-unit-files --no-legend "$s.service" 2>/dev/null) ]]; then
        service="$s"
        break
    fi
done

# another file in the same directory naming "qs" would fight this one, and
# ananicy does not define which of two rules for one name wins. The shipped
# defaults are not a conflict: outranking those is the whole point. Neither is a
# file whose "qs" rule is identical to ours - both agree, so whichever wins, the
# result is the same.
qs_rule() { grep -h '"name"[[:space:]]*:[[:space:]]*"qs"' "$1" 2>/dev/null | tr -s '[:space:]' ' '; }

conflicting_rules() {
    local ours f
    ours=$(qs_rule "$SRC/$RULE_NAME")
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        [[ $(qs_rule "$f") == "$ours" ]] && continue
        echo "$f"
    done < <(grep -rl '"name"[[:space:]]*:[[:space:]]*"qs"' "$ANANICY_D" 2>/dev/null \
        | grep -v "/$RULE_NAME\$" | grep -v '/00-default/' || true)
}

# a failed restart is not fatal either way: the rule is a file on disk, and
# ananicy reads it whenever it next starts
reload_ananicy() {
    [[ -n $service ]] || return 0
    systemctl is-active --quiet "$service" || return 0
    if systemctl restart "$service" 2>/dev/null; then
        echo "==> Restarted $service"
    else
        echo "NOTE: could not restart $service; the rule applies when it next starts."
    fi
}

if [[ $STATUS == 1 ]]; then
    echo "service=$service"
    if [[ -n $service ]] && systemctl is-active --quiet "$service"; then
        echo "active=1"
    else
        echo "active=0"
    fi
    [[ -f $DEST ]] && echo "rule=1" || echo "rule=0"
    # /proc/<pid>/stat holds the comm in brackets and it may contain spaces, so
    # count fields from after the closing one: nice is the 17th of those
    if [[ -n $STATUS_PID && -r /proc/$STATUS_PID/stat ]]; then
        echo "nice=$(awk '{sub(/.*\) /, ""); print $17}' "/proc/$STATUS_PID/stat")"
    fi
    echo "target=$TARGET_NICE"
    echo "conflict=$(conflicting_rules | head -1)"
    exit 0
fi

if [[ $REMOVE == 1 ]]; then
    if [[ -e $DEST ]]; then
        rm -f "$DEST"
        echo "Removed $DEST"
    else
        echo "Nothing to remove at $DEST"
    fi
    reload_ananicy
    echo "The shell keeps its current priority until it is restarted."
    exit 0
fi

if [[ -z $service ]]; then
    echo "ananicy is not installed; nothing renices the shell, so there is nothing to fix."
    echo "Install ananicy-cpp and run this again if you want the rule in place."
    exit 0
fi

others=$(conflicting_rules)
if [[ -n $others ]]; then
    echo "NOTE: these also set a rule for \"qs\" and may win over this one:"
    sed 's/^/      /' <<<"$others"
    echo "      Remove them if the priority below is not what you asked for."
fi

install -Dm644 "$SRC/$RULE_NAME" "$DEST"
echo "==> Installed $DEST"

reload_ananicy

# ananicy will not revisit a process it has already classified
mapfile -t pids < <(pgrep -x qs || true)
if [[ ${#pids[@]} -gt 0 ]]; then
    # the rule is already in place by now, so a failure here is worth a word
    # rather than an abort: the next launch of the shell picks it up regardless
    if renice -n "$TARGET_NICE" -p "${pids[@]}" >/dev/null 2>&1; then
        for p in "${pids[@]}"; do
            ionice -c2 -n2 -p "$p" 2>/dev/null || true
        done
        echo "==> Repriced ${#pids[@]} running qs process(es) to nice $TARGET_NICE"
    else
        echo "NOTE: could not renice the running shell (needs root)."
        echo "      It picks the rule up the next time it starts."
    fi
fi
