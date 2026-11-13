#!/usr/bin/env bash
# Glasdock — install or update the widgets of this repository.
#
#   ./install.sh                    sync shared code and install/update every widget
#   ./install.sh glasplayer         only the given widget(s)
#   ./install.sh --sync-only        only copy shared/ into each widget (for development)
#   ./install.sh --restart          also restart plasmashell afterwards
#   ./install.sh --no-blur          skip building the blur helper plugin
#
# The blur helper (plugin/, a small C++ QML module) lets the widgets ask KWin
# to blur the desktop behind their glass. It is built with CMake and installed
# to ~/.local/lib/qt6/qml; that folder is added to QML_IMPORT_PATH for the
# session (~/.config/environment.d/90-glasdock.conf). Without it, everything
# works except the blur.
#
# Each Plasma widget must contain all of its files, so the code in shared/ is
# copied to <widget>/contents/ui/shared/ before installing (that copy is ignored
# by git).
set -euo pipefail

cd "$(dirname "$0")"

ALL=(glasdock glasplayer glasweather)
widgets=()
sync_only=false
restart=false
build_blur=true

for arg in "$@"; do
    case "$arg" in
        --sync-only) sync_only=true ;;
        --restart) restart=true ;;
        --no-blur) build_blur=false ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *)
            if [[ ! -f "$arg/metadata.json" ]]; then
                echo "Unknown widget: $arg (available: ${ALL[*]})" >&2
                exit 1
            fi
            widgets+=("$arg")
            ;;
    esac
done
[[ ${#widgets[@]} -eq 0 ]] && widgets=("${ALL[@]}")

for w in "${widgets[@]}"; do
    dest="$w/contents/ui/shared"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -r shared/. "$dest/"
    echo "synced shared/ -> $dest"

    $sync_only && continue

    id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['KPlugin']['Id'])" "$w/metadata.json")
    if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$id"; then
        kpackagetool6 -t Plasma/Applet -u "$w"
    else
        kpackagetool6 -t Plasma/Applet -i "$w"
    fi
done

install_blur_helper() {
    local qmldir="$HOME/.local/lib/qt6/qml"
    if ! command -v cmake >/dev/null; then
        echo "blur helper skipped: cmake not found"
        return
    fi
    local gen=()
    command -v ninja >/dev/null && gen=(-G Ninja)
    if ! cmake -S plugin -B plugin/build "${gen[@]}" -DCMAKE_BUILD_TYPE=Release >/dev/null \
        || ! cmake --build plugin/build >/dev/null; then
        echo "blur helper skipped: build failed (needs Qt6 and KF6 WindowSystem development files)"
        return
    fi
    local dest="$qmldir/org/glasdock/blur"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp plugin/build/qml/org/glasdock/blur/qmldir \
       plugin/build/qml/org/glasdock/blur/*.so \
       plugin/build/qml/org/glasdock/blur/*.qmltypes "$dest/"
    echo "installed blur helper -> $dest"

    # let plasmashell find it: for future sessions...
    local envfile="$HOME/.config/environment.d/90-glasdock.conf"
    if [[ ! -f "$envfile" ]]; then
        mkdir -p "$(dirname "$envfile")"
        printf '# added by Glasdock install.sh (blur helper plugin)\nQML_IMPORT_PATH=%s${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}\n' "$qmldir" > "$envfile"
        echo "added $envfile"
    fi
    # ...and for the running session
    local current
    current=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^QML_IMPORT_PATH=//p')
    case ":$current:" in
        *":$qmldir:"*) ;;
        *)
            systemctl --user set-environment "QML_IMPORT_PATH=$qmldir${current:+:$current}"
            echo "QML_IMPORT_PATH set for this session (restart Plasma to use the blur)"
            ;;
    esac
}

if $build_blur && ! $sync_only; then
    install_blur_helper
fi

if $restart && ! $sync_only; then
    systemctl --user restart plasma-plasmashell
    echo "plasmashell restarted"
elif ! $sync_only; then
    echo "Restart Plasma to load the changes: systemctl --user restart plasma-plasmashell"
fi
