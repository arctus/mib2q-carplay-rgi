#!/bin/sh
# M.I.B. -> Advanced Settings -> Run Custom Script: Android Auto in the Virtual Cockpit OFF.
#
# Removes /mnt/app/carplay_aa.enabled, so the patched HMI leaves Android Auto completely
# stock again.  CarPlay is not affected.  REBOOT the head unit after running this.
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
echo "custom.sh: Android Auto in the Virtual Cockpit OFF"
mount -uw /mnt/app 2>/dev/null || echo "custom.sh: mount -uw /mnt/app failed"
rm -f "$M"
if [ -e "$M" ]; then
    echo "FAILED: $M still present (is /mnt/app read-only?)"
    exit 1
fi
sync
echo "DONE. Android Auto in the Virtual Cockpit OFF."
echo "Reboot the head unit to apply."
