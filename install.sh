#!/usr/bin/env bash
# Glasdock — install or update the widgets of this repository.
#
#   ./install.sh                    sync shared code and install/update every widget
#   ./install.sh glasplayer         only the given widget(s)
#   ./install.sh --sync-only        only copy shared/ into each widget (for development)
#   ./install.sh --restart          also restart plasmashell afterwards
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

for arg in "$@"; do
    case "$arg" in
        --sync-only) sync_only=true ;;
        --restart) restart=true ;;
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

if $restart && ! $sync_only; then
    systemctl --user restart plasma-plasmashell
    echo "plasmashell restarted"
elif ! $sync_only; then
    echo "Restart Plasma to load the changes: systemctl --user restart plasma-plasmashell"
fi
