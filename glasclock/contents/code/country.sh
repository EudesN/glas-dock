#!/bin/sh
# Glasclock: print the ISO country code (e.g. BR) of the system time zone.
# Old aliases such as Brazil/East are resolved to their canonical zone first.
tz=$(timedatectl show -p Timezone --value 2>/dev/null)
[ -z "$tz" ] && tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
canon=$(awk -v z="$tz" '$1 == "L" && $3 == z { print $2 }' /usr/share/zoneinfo/tzdata.zi 2>/dev/null)
awk -v z="${canon:-$tz}" '!/^#/ && $3 == z { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null
