# shellcheck shell=bash
#
# build-env.sh — where this shell installs to, and how to keep the build agreeing
# with that. Sourced by rebuild.sh, update.sh and shell-update.sh; not executable.
#
# Quickshell only finds the shell under $XDG_CONFIG_DIRS, which is /etc/xdg on a
# default system, and Qt only finds the plugins under /usr/lib/qt6/qml. Both of
# those paths come from configuring the build with CMAKE_INSTALL_PREFIX=/.
#
# A plain `cmake -B build` defaults the prefix to /usr/local instead. Nothing
# reads /usr/local/etc/xdg/quickshell or /usr/local/lib/qt6/qml, so the install
# step reports success, writes a complete copy of the shell that nothing will
# ever load, and leaves the previously installed build running. The symptom is a
# shell that looks several versions old however many times you reinstall it.
#
# Guarding the configure step on `[[ ! -d build ]]` does not catch that: a build
# directory that already exists with the wrong prefix is reused exactly as it is.
# So the cached prefix gets checked on every run instead of only on first setup.

CAELESTIA_PREFIX=/

# What a prefix=/usr/local install leaves behind: inert, but it shadows nothing
# and only confuses the next person to go looking, so rebuild.sh offers to clear
# it out once a correct install is in place.
CAELESTIA_STRAY_DIRS=(
    /usr/local/etc/xdg/quickshell/caelestia
    /usr/local/lib/qt6/qml/Caelestia
    /usr/local/lib/caelestia
)

# A file installed verbatim from the source tree, used to tell whether the thing
# now on the system is the thing in this checkout. utils/ ships as-is (see the
# install(DIRECTORY) loop in CMakeLists.txt), and this is the file whose absence
# shows up as a desktop missing most of its widgets.
CAELESTIA_SENTINEL=utils/WidgetCatalog.qml

# The prefix build/ is configured for; empty when it is not configured at all.
caelestia_cached_prefix() {
    [[ -f build/CMakeCache.txt ]] || return 0
    sed -n 's/^CMAKE_INSTALL_PREFIX:PATH=//p' build/CMakeCache.txt | head -1
}

# Configures build/ when missing, repoints it when it would install somewhere
# nothing loads, and stays quiet when it is already right. Echoes a line about
# what it did so callers can decide how loudly to report it.
caelestia_configure_build() {
    local cached
    cached=$(caelestia_cached_prefix)

    if [[ -z $cached ]]; then
        echo "configuring build (prefix $CAELESTIA_PREFIX)"
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$CAELESTIA_PREFIX"
    elif [[ $cached != "$CAELESTIA_PREFIX" ]]; then
        # Only the prefix is corrected. The build type is left as whoever
        # configured this tree set it, so repairing a prefix does not silently
        # trigger a full rebuild on top of it.
        echo "build was configured for prefix '$cached', which nothing loads; repointing at '$CAELESTIA_PREFIX'"
        cmake -B build -DCMAKE_INSTALL_PREFIX="$CAELESTIA_PREFIX"
    fi
}

# Whichever of the stray dirs currently exist, one per line.
caelestia_stray_dirs() {
    local d
    for d in "${CAELESTIA_STRAY_DIRS[@]}"; do
        [[ -e $d ]] && echo "$d"
    done
    return 0
}

# Where a prefix=/ install puts the shell's QML.
caelestia_installed_qsconfdir() {
    echo /etc/xdg/quickshell/caelestia
}
