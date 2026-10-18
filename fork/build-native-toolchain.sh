#!/bin/bash
# Install the qnx65-armv7-toolchain natively (no Docker) on Ubuntu 24.04, as root.
# Mirrors the image's base-8.5 + base-env stages: QNX 6.5 SDP, GCC 8.5.0, gas 2.38.
# Use with fork/bin/docker so luka's scripts run unchanged. Used for the 2026-10-18 baseline.
#
#   sudo fork/build-native-toolchain.sh /path/to/qnx65-armv7-toolchain   (~40 min on 2 cores)
set -euo pipefail
TC=$(cd "${1:?usage: $0 <qnx65-armv7-toolchain checkout>}" && pwd)
W=${WORK:-/tmp/qnx-native}; mkdir -p "$W"
dpkg --add-architecture i386; apt-get update
apt-get install -y libc6:i386 libstdc++6:i386 zlib1g:i386 build-essential libgmp-dev libmpfr-dev \
    libmpc-dev flex bison texinfo file xz-utils curl git cmake meson ninja-build pkg-config
mkdir -p /opt/qnx650 && cp -a "$TC/sdp/." /opt/qnx650/
export QNX_HOST=/opt/qnx650/host/linux/x86 QNX_TARGET=/opt/qnx650/target/qnx6 QNX_CONFIGURATION=/opt/qnx650/etc/qnx
export PATH=$QNX_HOST/usr/bin:/usr/local/bin:/usr/bin:/bin LD_LIBRARY_PATH=$QNX_HOST/usr/lib
cd "$W"
# binutils 2.38: GNU tarball (Ubuntu's orig tarball has the same SHA-256)
[ -f binutils-2.38.tar.xz ] || curl -fsSL -o binutils-2.38.tar.xz https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.xz \
  || curl -fsSL -o binutils-2.38.tar.xz http://archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_2.38.orig.tar.xz
echo "e316477a914f567eccc34d5d29785b8b0f5a10208d36bbacedcc39048ecfe024  binutils-2.38.tar.xz" | sha256sum -c -
# gcc 8.5.0: GNU tarball, else the GitHub mirror tag packed the same way
if [ ! -f gcc-8.5.0.tar.xz ]; then
  if curl -fsSL -o gcc-8.5.0.tar.xz https://ftp.gnu.org/gnu/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz; then
    echo "d308841a511bb830a6100397b0042db24ce11f642dab6ea6ee44842e5325ed50  gcc-8.5.0.tar.xz" | sha256sum -c -
  else
    rm -f gcc-8.5.0.tar.xz; git clone -q --depth 1 --branch releases/gcc-8.5.0 https://github.com/gcc-mirror/gcc gcc-8.5.0
    rm -rf gcc-8.5.0/.git && tar -cJf gcc-8.5.0.tar.xz gcc-8.5.0 && rm -rf gcc-8.5.0
  fi
fi
bash "$TC/binutils/build.sh" "$W/binutils-2.38.tar.xz" /binutils-out
bash "$TC/gcc/build.sh" "$W/gcc-8.5.0.tar.xz" /gcc-out
H=$QNX_HOST/usr
cp -a /gcc-out/. "$H/"
cp /binutils-out/bin/arm-unknown-nto-qnx6.5.0eabi-as "$H/bin/arm-unknown-nto-qnx6.5.0eabi-as-2.38"
ln -sf arm-unknown-nto-qnx6.5.0eabi-as-2.38 "$H/bin/arm-unknown-nto-qnx6.5.0eabi-as"
ln -sf arm-unknown-nto-qnx6.5.0eabi-as-2.38 "$H/bin/ntoarmv7-as"
mkdir -p /opt/tools /opt/qnx-cross && cp -a "$TC/tools/." /opt/tools/ && cp -a "$TC/cross/." /opt/qnx-cross/
ln -sf /opt/tools/qcc/bin/qcc "$H/bin/qcc"
"$H/bin/arm-unknown-nto-qnx6.5.0eabi-gcc" --version | head -1
"$H/bin/arm-unknown-nto-qnx6.5.0eabi-as" --version | head -1
