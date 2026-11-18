#!/bin/sh
# Glasclock: print the ISO country code (e.g. BR) of the system time zone.
#
# The zone is looked up in zone.tab first. Only when it is not listed there
# (old aliases such as Brazil/East) is it resolved through tzdata.zi links,
# whose lines read "L <target> <link>". Resolving first was wrong: since tz
# 2022 many zones are links to a zone of another country (Europe/Amsterdam ->
# Europe/Brussels, Europe/Oslo -> Europe/Berlin), which gave Dutch, Norwegian
# … users the neighbour's holidays.
tz=$(timedatectl show -p Timezone --value 2>/dev/null)
[ -z "$tz" ] && tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
[ -z "$tz" ] && exit 0

lookup() {
    awk -v z="$1" '!/^#/ && $3 == z { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null
}

cc=$(lookup "$tz")
if [ -z "$cc" ]; then
    target=$(awk -v z="$tz" '$1 == "L" && $3 == z { print $2; exit }' /usr/share/zoneinfo/tzdata.zi 2>/dev/null)
    [ -n "$target" ] && cc=$(lookup "$target")
fi
printf '%s\n' "$cc"
