#!/usr/bin/env bash
# net-probe.sh [out] — the one thing the greeter cannot read for itself.
#
# the login screen is sandboxed down to plain file reads, and neither the name
# of the network nor the strength of the link is in sysfs: wext's
# /proc/net/wireless is empty on most current drivers, and NetworkManager
# keeps the name in /etc/NetworkManager/system-connections, which is root's
# alone. so this runs as root -- every caelestia-sddm-net.timer, which
# install-theme.sh sets up -- and leaves them where the greeter can read them:
# a flat ini in /run, world readable, holding nothing secret. the name of the
# network, the strength as a percentage, and when it was written, so a greeter
# reading a file left behind by some other day can tell and say less.
#
# without any of this the chip still knows from sysfs whether wi-fi is up; it
# just cannot say which one or how well.

set -euo pipefail

OUT="${1:-/run/caelestia-sddm/net.conf}"

iface=""
state=down
ssid=""
signal=""

# the wireless interfaces the kernel admits to, an up one for preference
for d in /sys/class/net/*; do
    [[ -d "$d/wireless" || -e "$d/phy80211" ]] || continue
    name=$(basename "$d")
    [[ -n $iface ]] || iface=$name
    if [[ $(cat "$d/operstate" 2>/dev/null || true) == up ]]; then
        iface=$name
        state=up
        break
    fi
done

# the classic wext curve, for when nothing better is on offer: -100 dBm is
# nothing, -50 and up is everything
pct_from_dbm() {
    local dbm=$1 pct
    pct=$(( 2 * (dbm + 100) ))
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    printf '%s' "$pct"
}

if [[ $state == up ]]; then
    # NetworkManager first, so the greeter's percentage is the one the desktop
    # itself shows -- it reads the link quality rather than the raw dBm. -t
    # escapes a colon inside a field as \:, so the fields are split on an
    # unescaped one and the escapes undone after
    if command -v nmcli >/dev/null 2>&1; then
        while IFS= read -r line; do
            [[ $line == yes:* ]] || continue
            rest=$(sed 's/\\:/\x01/g' <<< "${line#yes:}")
            signal=${rest##*:}
            ssid=$(tr '\001' ':' <<< "${rest%:*}")
            break
        done < <(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null || true)
    fi
    # iw stands in on a machine NetworkManager does not run: the name as the
    # driver has it, and the signal in dBm, on the classic wext curve
    if [[ -z $ssid || -z $signal ]] && command -v iw >/dev/null 2>&1; then
        link=$(iw dev "$iface" link 2>/dev/null || true)
        [[ -n $ssid ]] || ssid=$(sed -n 's/^[[:space:]]*SSID:[[:space:]]*//p' <<< "$link" | head -1)
        if [[ -z $signal ]]; then
            dbm=$(sed -n 's/^[[:space:]]*signal:[[:space:]]*\(-\?[0-9]\+\).*/\1/p' <<< "$link" | head -1)
            [[ -n ${dbm:-} ]] && signal=$(pct_from_dbm "$dbm")
        fi
    fi
fi

# a name is whatever someone called their router, so it loses anything that
# would make the ini unreadable and nothing else
ssid=$(printf '%s' "$ssid" | tr -d '\r\n' | sed 's/[[:space:]]*$//')
[[ $signal =~ ^[0-9]+$ ]] || signal=""

install -d -m755 "$(dirname "$OUT")"
TMP=$(mktemp "$OUT.XXXXXX")
trap 'rm -f "$TMP"' EXIT
{
    echo "# written by cykler-caelestia's net-probe.sh for the login screen's chips"
    echo "iface=$iface"
    echo "state=$state"
    echo "ssid=$ssid"
    echo "signal=$signal"
    echo "at=$(date +%s)"
} > "$TMP"
chmod 644 "$TMP"
mv -f "$TMP" "$OUT"
trap - EXIT
