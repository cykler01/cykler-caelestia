#!/usr/bin/env bash
# install-theme.sh [dest] [--fingerprint | --no-fingerprint] [--no-network]
# [--current] — installs cykler-caelestia's sddm theme. needs root: install.sh
# runs it through sudo, and running it by hand updates the theme alone.
# --fingerprint lets the login screen take a fingerprint (two lines in
# /etc/pam.d/sddm), --no-fingerprint takes them out; without either, pam is
# left as it is. --no-network takes out the timer that tells the greeter which
# wi-fi it is on. --current also makes it the theme sddm shows.
#
# root owns the theme. the one writable part is users/, sticky and
# world-writable like /tmp, where each account's sync-sddm.sh keeps its own
# wallpaper and palette, so the greeter can wear whoever is picked.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST=/usr/share/sddm/themes/cykler-caelestia
FINGER=""
NETWORK=on
CURRENT=0
for arg in "$@"; do
    case $arg in
        --fingerprint) FINGER=on ;;
        --no-fingerprint) FINGER=off ;;
        --no-network) NETWORK=off ;;
        --current) CURRENT=1 ;;
        *) DEST=$arg ;;
    esac
done
# overridable so the pam and theme edits can be tried on a copy
PAM_SDDM="${CAELESTIA_PAM_SDDM:-/etc/pam.d/sddm}"
SDDM_CONF_D="${CAELESTIA_SDDM_CONF_D:-/etc/sddm.conf.d}"

if [[ $EUID -ne 0 ]]; then
    echo "install-theme.sh: needs root, run it with sudo" >&2
    exit 1
fi

install -d -m755 "$DEST"
cp -r "$SRC/sddm/cykler-caelestia/." "$DEST/"

# the greeter runs as its own user, so the font it draws in rides along with
# the theme rather than in anyone's home
install -Dm644 "$SRC/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf" \
    "$DEST/fonts/GoogleSansFlex.ttf"
install -Dm644 "$SRC/assets/google-sans-flex/LICENSE" "$DEST/fonts/LICENSE"

# a shared background.jpg predates users/: one account's wallpaper, shown for
# everyone else. an account that has not painted yet gets a flat surface
rm -f "$DEST/background.jpg"

# -h, so a planted link changes nothing else
find "$DEST" -path "$DEST/users" -prune -o -exec chown -h root:root {} +

# the greeter decodes a live wallpaper in software rather than waking every
# hardware decoder (~3s, and a hybrid laptop's dGPU lit at the login screen),
# and qml may only read sysfs for the glance chips with QML_XHR_ALLOW_FILE_READ.
# a GreeterEnvironment set anywhere else is left alone, since this would replace it
GREETER_CONF="$SDDM_CONF_D/caelestia-greeter.conf"
if ! grep -qs '^[[:space:]]*GreeterEnvironment=.' /etc/sddm.conf $(ls "$SDDM_CONF_D"/*.conf 2>/dev/null | grep -vx "$GREETER_CONF"); then
    install -d -m755 "$SDDM_CONF_D"
    printf '%s\n' \
        "# written by cykler-caelestia's install-theme.sh: the greeter decodes the live" \
        "# wallpaper in software rather than waking every GPU to look for a decoder," \
        "# and reads the battery and the network state for its chips" \
        "[General]" \
        "GreeterEnvironment=QT_FFMPEG_DECODING_HW_DEVICE_TYPES=,QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=,QML_XHR_ALLOW_FILE_READ=1" \
        > "$GREETER_CONF"
    chmod 644 "$GREETER_CONF"
fi

if [[ -L "$DEST/users" || ( -e "$DEST/users" && ! -d "$DEST/users" ) ]]; then
    rm -f "$DEST/users"
fi
install -d "$DEST/users"
chown root:root "$DEST/users"
chmod 1777 "$DEST/users"

# every account sddm would list gets its directory now, so no other account
# can take the name first
UID_LO=$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs 2>/dev/null || true)
UID_HI=$(awk '$1 == "UID_MAX" { print $2 }' /etc/login.defs 2>/dev/null || true)
UID_LO=${UID_LO:-1000}
UID_HI=${UID_HI:-60000}
getent passwd | while IFS=: read -r name _ uid gid _; do
    (( uid >= UID_LO && uid <= UID_HI )) || continue
    dir="$DEST/users/$name"
    if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) ]]; then
        rm -f "$dir"
    fi
    install -d -m755 "$dir"
    chown -R -h "$uid:$gid" "$dir"
done

# a fingerprint at the login screen. sddm checks one attempt at a time through
# its own pam service: a typed password goes first, an empty one reaches the
# reader and ends at pam_deny so faillock never counts it. marked, so it comes out again
FP_HELPER="$DEST/pam-empty-password"
install -Dm755 "$SRC/sddm/pam-empty-password" "$FP_HELPER"
FP_BEGIN="# >>> cykler-caelestia: fingerprint login"
FP_END="# <<< cykler-caelestia: fingerprint login"
pam_module() {
    local d
    for d in /usr/lib/security /usr/lib64/security /lib/security /lib/x86_64-linux-gnu/security; do
        [[ -e "$d/$1" ]] && return 0
    done
    return 1
}
if [[ $FINGER == off && -f "$PAM_SDDM" ]]; then
    sed -i "/^$FP_BEGIN/,/^$FP_END/d" "$PAM_SDDM"
elif [[ $FINGER == on && -f "$PAM_SDDM" ]]; then
    if ! pam_module pam_fprintd.so; then
        echo "install-theme.sh: pam_fprintd.so is not installed (fprintd), leaving $PAM_SDDM alone" >&2
    else
        [[ -e "$PAM_SDDM.caelestia-backup" ]] || cp -p "$PAM_SDDM" "$PAM_SDDM.caelestia-backup"
        sed -i "/^$FP_BEGIN/,/^$FP_END/d" "$PAM_SDDM"
        awk -v begin="$FP_BEGIN" -v end="$FP_END" -v helper="$FP_HELPER" '
            !done && /^[[:space:]]*-?auth[[:space:]]/ {
                print begin " (install-theme.sh --no-fingerprint takes it out)"
                print "auth        [success=3 new_authtok_reqd=3 default=ignore]  pam_unix.so try_first_pass likeauth nullok nodelay"
                print "auth        [success=ignore default=2]  pam_exec.so quiet expose_authtok " helper
                print "auth        sufficient  pam_fprintd.so max-tries=1 timeout=10"
                print "auth        [default=die]  pam_deny.so"
                print end
                done = 1
            }
            { print }
        ' "$PAM_SDDM" > "$PAM_SDDM.caelestia-tmp"
        cat "$PAM_SDDM.caelestia-tmp" > "$PAM_SDDM"
        rm -f "$PAM_SDDM.caelestia-tmp"
    fi
fi

# ── what the greeter cannot read for itself ────────────────────────────────
# the name of the wi-fi and the strength of the link are in neither sysfs nor
# /proc, and a greeter may only read files. a root timer writes them into /run
# every twenty seconds, where the chip picks them up; --no-network takes it
# out again and the chip is left knowing only whether wi-fi is up at all
NET_PROBE="$DEST/net-probe.sh"
NET_UNIT="${CAELESTIA_SYSTEMD_DIR:-/etc/systemd/system}/caelestia-sddm-net.service"
NET_TIMER="${CAELESTIA_SYSTEMD_DIR:-/etc/systemd/system}/caelestia-sddm-net.timer"
if [[ $NETWORK == off ]]; then
    rm -f "$NET_PROBE"
    if command -v systemctl >/dev/null && [[ -e $NET_TIMER ]]; then
        systemctl disable --now caelestia-sddm-net.timer >/dev/null 2>&1 || true
        rm -f "$NET_UNIT" "$NET_TIMER"
        systemctl daemon-reload || true
    else
        rm -f "$NET_UNIT" "$NET_TIMER"
    fi
    echo "install-theme.sh: the wi-fi name and signal are left out"
else
    install -Dm755 "$SRC/sddm/net-probe.sh" "$NET_PROBE"
    if command -v systemctl >/dev/null; then
        install -d -m755 "$(dirname "$NET_UNIT")"
        printf '%s\n' \
            "# written by cykler-caelestia's install-theme.sh" \
            "[Unit]" \
            "Description=Wi-Fi name and signal for the cykler-caelestia login screen" \
            "ConditionPathExists=$NET_PROBE" \
            "" \
            "[Service]" \
            "Type=oneshot" \
            "RuntimeDirectory=caelestia-sddm" \
            "RuntimeDirectoryMode=0755" \
            "RuntimeDirectoryPreserve=yes" \
            "ExecStart=$NET_PROBE /run/caelestia-sddm/net.conf" \
            > "$NET_UNIT"
        printf '%s\n' \
            "# written by cykler-caelestia's install-theme.sh" \
            "[Unit]" \
            "Description=Keep the login screen's wi-fi chip current" \
            "" \
            "[Timer]" \
            "OnBootSec=5s" \
            "OnUnitActiveSec=20s" \
            "AccuracySec=5s" \
            "" \
            "[Install]" \
            "WantedBy=timers.target" \
            > "$NET_TIMER"
        chmod 644 "$NET_UNIT" "$NET_TIMER"
        systemctl daemon-reload
        systemctl enable --now caelestia-sddm-net.timer >/dev/null
    else
        echo "install-theme.sh: no systemctl here, so nothing will keep /run/caelestia-sddm/net.conf current -- the wi-fi chip will show only whether wi-fi is up" >&2
    fi
fi

# the greeter offers a fingerprint only where pam takes one, this edit or the
# machine's own
FP_ON=false
if [[ -f "$PAM_SDDM" ]] && grep -qE '^[[:space:]]*-?auth[[:space:]].*pam_fprintd\.so' "$PAM_SDDM"; then
    FP_ON=true
fi
printf '\n# set by install-theme.sh: whether /etc/pam.d/sddm takes a fingerprint\nfingerprintLogin=%s\n' "$FP_ON" >> "$DEST/theme.conf"

# NOTE(fork): which theme sddm shows. sddm reads /etc/sddm.conf first and then
# /etc/sddm.conf.d/*.conf in name order, so the LAST file to set Current wins --
# the opposite of what lucid's installer assumed. On a machine that already has
# a conf.d file naming another caelestia theme, writing to /etc/sddm.conf would
# be silently overridden by it, so the line goes in a conf.d file named to sort
# last instead.
if [[ $CURRENT -eq 1 ]]; then
    name=$(basename "$DEST")
    install -d -m755 "$SDDM_CONF_D"
    THEME_CONF="$SDDM_CONF_D/zz-cykler-caelestia.conf"
    printf '%s\n' \
        "# written by cykler-caelestia's install-theme.sh. named to sort last:" \
        "# sddm lets the last conf.d file to set Current win" \
        "[Theme]" \
        "Current=$name" \
        > "$THEME_CONF"
    chmod 644 "$THEME_CONF"

    # anything else still naming a theme is worth saying out loud rather than
    # leaving someone to wonder why the greeter did not change
    others=$(grep -ls '^[[:space:]]*Current=' /etc/sddm.conf "$SDDM_CONF_D"/*.conf 2>/dev/null | grep -vx "$THEME_CONF" || true)
    if [[ -n "$others" ]]; then
        echo "install-theme.sh: these also set a theme, and this one now outranks them:" >&2
        printf '  %s\n' $others >&2
    fi
fi

echo "install-theme.sh: installed to $DEST"
