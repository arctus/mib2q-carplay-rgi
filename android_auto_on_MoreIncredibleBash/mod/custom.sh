#!/bin/sh
# M.I.B. -> Advanced Settings -> Run Custom Script: Android Auto in the Virtual Cockpit ON.
#
# Creates /mnt/app/carplay_aa.enabled.  With it, the patched HMI bridges an Android Auto
# phone's next-turn data into the same route-guidance chain CarPlay uses: maneuver arrow,
# distance bar and route text in the Virtual Cockpit and the HUD, plus Android Auto cover art
# on the cluster media screen.  Without it Android Auto stays completely stock.
# The HMI reads the marker when it starts, so REBOOT the head unit after running this.
#
# QNX 6.5 /bin/sh is ksh (pdksh) - this script stays inside its portable subset.
# SPDX-License-Identifier: GPL-3.0-or-later
set -u
PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/usr/bin
export PATH
unset LD_PRELOAD 2>/dev/null

case $0 in */*) D=${0%/*} ;; *) D=. ;; esac
D=$(cd "$D" && pwd) || exit 1

if [ ! -d /mnt/app/eso/hmi/lsd ] && [ -d /net/mmx/mnt/app/eso/hmi/lsd ]; then
    exec on -f mmx /bin/sh "$D/custom.sh" "$@"
fi

M=/mnt/app/carplay_aa.enabled
echo "custom.sh: Android Auto in the Virtual Cockpit ON"
mount -uw /mnt/app 2>/dev/null || echo "custom.sh: mount -uw /mnt/app failed"
: > "$M" 2>/dev/null
if [ ! -e "$M" ]; then
    echo "FAILED: could not create $M (is /mnt/app read-only?)"
    exit 1
fi
rm -f /mnt/app/carplay_aa.disabled
sync
echo "DONE. Android Auto in the Virtual Cockpit ON."
echo "Reboot the head unit to apply."
