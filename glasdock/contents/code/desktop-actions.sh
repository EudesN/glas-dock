#!/bin/sh
# Glasdock: print the [Desktop Action …] entries of a .desktop file as
#   <id>\t<localized Name>\t<Icon>\t<Exec command>
raw="$1"
loc="${2:-${LC_MESSAGES:-${LANG:-}}}"
loc="${loc%%.*}"
lang="${loc%%_*}"

[ -z "$raw" ] && exit 0

file=""
case "$raw" in
    file://*)
        p="${raw#file://}"
        [ -f "$p" ] && file="$p"
        ;;
    /*)
        [ -f "$raw" ] && file="$raw"
        ;;
esac

if [ -z "$file" ]; then
    id="$raw"
    id="${id#application://}"
    id="${id#applications:}"
    id="${id##*/}"
    id="${id%.desktop}"
    [ -z "$id" ] && exit 0
    for d in "$HOME/.local/share/applications" \
             "$HOME/.local/share/flatpak/exports/share/applications" \
             "/var/lib/flatpak/exports/share/applications" \
             "/usr/local/share/applications" \
             "/usr/share/applications" \
             "/var/lib/snapd/desktop/applications"; do
        if [ -f "$d/$id.desktop" ]; then
            file="$d/$id.desktop"
            break
        fi
    done
fi

[ -z "$file" ] || [ ! -f "$file" ] && exit 0

awk -v loc="$loc" -v lang="$lang" '
    /^\[Desktop Entry\]/ { sec = "entry"; next }
    /^\[Desktop Action / {
        sec = $0
        sub(/^\[Desktop Action /, "", sec)
        sub(/\].*$/, "", sec)
        next
    }
    /^\[/ { sec = ""; next }
    sec == "entry" {
        if ($0 ~ /^Actions=/) {
            acts = substr($0, 9)
        } else if ($0 ~ /^Icon=/) {
            defIcon = substr($0, 6)
        }
    }
    sec != "" && sec != "entry" {
        if ($0 ~ /^Name=/) {
            name[sec] = substr($0, 6)
        } else if (loc != "" && index($0, "Name[" loc "]=") == 1) {
            nameLoc[sec] = substr($0, length("Name[" loc "]=") + 1)
        } else if (lang != "" && index($0, "Name[" lang "]=") == 1) {
            nameLang[sec] = substr($0, length("Name[" lang "]=") + 1)
        } else if ($0 ~ /^Icon=/) {
            icon[sec] = substr($0, 6)
        } else if ($0 ~ /^Exec=/) {
             cmd = substr($0, 6)
             gsub(/ %[fFuUdDnNickvm]/, "", cmd)
             exec[sec] = cmd
        }
    }
    END {
        n = split(acts, arr, ";")
        for (i = 1; i <= n; i++) {
            a = arr[i]
            if (a == "" || exec[a] == "")
                continue
            nm = nameLoc[a] != "" ? nameLoc[a] : (nameLang[a] != "" ? nameLang[a] : name[a])
            if (nm == "")
                continue
            ic = icon[a] != "" ? icon[a] : defIcon
            printf "%s\t%s\t%s\t%s\n", a, nm, ic, exec[a]
        }
    }
' "$file"
