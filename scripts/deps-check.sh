# shellcheck shell=bash
#
# deps-check.sh — whether the AUR libraries the plugin links still resolve.
#
# The plugin links libcava, which ships from the AUR. It is built against
# whatever audio stack was installed the day the package was made, and pacman
# tracks the package it depends on, not the soname inside it. So when one of
# those libraries takes a soname bump (sndio 1.10 -> 1.11 moved libsndio.so.7
# to libsndio.so.9 on 2026-11-16) the installed libcava keeps asking for the
# old soname, pacman still reports "sndio" satisfied, and the shell dies on
# start with
#
#     libcaelestia-servicesplugin.so: libsndio.so.7: cannot open shared object file
#
# Reinstalling sndio cannot help: the file is gone from the repo too. The only
# fix is rebuilding libcava against what is installed now. These helpers let
# the install and update paths notice that and offer to do it, instead of
# leaving a shell that will not start. See issue #51.

# Path of the installed libcava; empty when it is not installed.
caelestia_libcava_path() {
    local lib
    if command -v ldconfig >/dev/null 2>&1; then
        lib=$(ldconfig -p 2>/dev/null | awk '$1 ~ /^libcava\.so\.[0-9]/ { print $NF; exit }')
    fi
    if [[ -n $lib && -e $lib ]]; then
        printf '%s\n' "$lib"
        return 0
    fi
    for lib in /usr/lib/libcava.so /usr/lib64/libcava.so; do
        if [[ -e $lib ]]; then
            printf '%s\n' "$lib"
            return 0
        fi
    done
    return 0
}

# The sonames the installed libcava asks for that are not on this system, one
# per line. Empty when it loads, and when it is not installed at all. LC_ALL=C
# because the loader translates its "not found" into the user's language.
caelestia_libcava_missing() {
    local lib out
    lib=$(caelestia_libcava_path)
    [[ -n $lib ]] || return 0
    # ldd exits nonzero when something is missing; the callers run under
    # `set -e`, so only its output is taken and its status dropped.
    out=$(LC_ALL=C ldd "$lib" 2>/dev/null) || true
    printf '%s\n' "$out" | awk '$2 == "=>" && $3 == "not" && $4 == "found" { print $1 }'
}

# Whether libcava is installed and something it links is missing, which is what
# a soname bump behind its back looks like.
caelestia_libcava_stale() {
    [[ -n $(caelestia_libcava_missing) ]]
}

# Clean rebuild of libcava through whichever AUR helper is installed. yay is
# told to discard its cached build tree (~/.cache/yay/libcava) first, because a
# rebuild from a cached tree can keep linking the old soname, which looks like
# the fix not working. Returns nonzero when there is no helper or the build
# fails.
caelestia_rebuild_libcava() {
    local helper
    for helper in yay paru; do
        command -v "$helper" >/dev/null 2>&1 || continue
        case "$helper" in
            yay) "$helper" -S --rebuild --answerclean All --noconfirm libcava ;;
            paru) "$helper" -S --rebuild --noconfirm libcava ;;
        esac
        return
    done
    printf 'no AUR helper (yay/paru) found\n' >&2
    return 1
}
