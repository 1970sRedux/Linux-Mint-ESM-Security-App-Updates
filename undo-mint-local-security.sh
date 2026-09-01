#!/usr/bin/env bash
# undo-mint-local-security.sh
# Reverses mint-local-security.sh: apt holds, PATH/linker hooks, /opt/local-security.
# Distro packages are not removed. After this, apt can install or upgrade them again.

set -euo pipefail

PREFIX=/opt/local-security
PROFILE=/etc/profile.d/local-security.sh
LDCONF=/etc/ld.so.conf.d/local-security.conf
APTPREF=/etc/apt/preferences.d/zz-local-security-hold

HOLD_PKGS=(
  imagemagick imagemagick-6-common imagemagick-6.q16 imagemagick-6.q16hdri
  imagemagick-doc
  ffmpeg ffmpeg-doc
  exiv2
  libheif-plugin-aomenc libheif-plugin-aomdec libheif-plugin-libde265
  libheif-examples
  libraw-bin libraw23t64 libraw23
)

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

echo "Removing apt pin $APTPREF (if present)"
rm -f "$APTPREF"

echo "Releasing apt holds"
apt-mark unhold "${HOLD_PKGS[@]}" >/dev/null 2>&1 || true

echo "Removing PATH hook $PROFILE"
rm -f "$PROFILE"

echo "Removing linker hook $LDCONF"
rm -f "$LDCONF"
ldconfig

if [[ -d $PREFIX ]]; then
  echo "Removing $PREFIX"
  rm -rf "$PREFIX"
else
  echo "$PREFIX already gone"
fi

echo
echo "Done. Open a new terminal so PATH is no longer pointed at $PREFIX/bin."
echo "Ubuntu/Mint copies of these programs are unchanged. apt may update them again."
echo "To put the local builds back: sudo ./mint-local-security.sh"
