#!/usr/bin/env bash
# mint-local-security.sh
#
# Build five high-churn Universe tools from upstream into /opt/local-security
# at versions that meet or beat Ubuntu Pro ESM backports on Ubuntu 24.04 / Mint 22,
# then stop apt from replacing the distro packages of those *tools*.
#
#   ImageMagick  7.1.2-30     (ESM on 24.04 is still 6.9.12.98 + patches)
#   FFmpeg       9.0.1
#   Exiv2        0.28.8
#   libheif      1.23.2        (security release, Aug 2026)
#   LibRaw       0.22.2        (camera RAW; Universe on 24.04)
#
# This does NOT patch Pix, xviewer, php-imagick, or any other apt binary that
# already linked Ubuntu's libmagickcore / libheif / libavcodec. Those processes
# keep loading /usr/lib until they are rebuilt. What you get is:
#   /opt/local-security/bin/{magick,ffmpeg,exiv2,heif-dec,simple_dcraw,raw-identify}
# on PATH for scripts, cron, and interactive use.
#
# Usage:
#   sudo ./mint-local-security.sh          # install or rebuild if older
#   sudo ./mint-local-security.sh status
#   sudo ./mint-local-security.sh hold     # apt-mark + pin only
#   sudo ./mint-local-security.sh unhold
#   sudo ./mint-local-security.sh uninstall
#
# Requires: build-essential, git, cmake, pkg-config, curl, autoconf, libtool.
# Network access to github.com and ffmpeg.org.

set -euo pipefail

PREFIX=/opt/local-security
SRC=${PREFIX}/src
BIN=${PREFIX}/bin
LIB=${PREFIX}/lib
PROFILE=/etc/profile.d/local-security.sh
LDCONF=/etc/ld.so.conf.d/local-security.conf
APTPREF=/etc/apt/preferences.d/zz-local-security-hold
STATE=${PREFIX}/versions

# Pinned floors. Bump these when you decide a newer tag is worth a rebuild.
IM_TAG="7.1.2-30"
FF_TAG="n9.0.1"
EX_TAG="v0.28.8"
HE_TAG="v1.23.2"
LR_TAG="0.22.2"

APT_HOLD_PKGS=(
  imagemagick imagemagick-6-common imagemagick-6.q16 imagemagick-6.q16hdri
  imagemagick-doc
  ffmpeg ffmpeg-doc
  exiv2
  libheif-plugin-aomenc libheif-plugin-aomdec libheif-plugin-libde265
  libheif-examples
  libraw-bin libraw23t64 libraw23
)

need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root (sudo $0 $*)" >&2
    exit 1
  fi
}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

ensure_dirs() {
  mkdir -p "$SRC" "$BIN" "$LIB" "$STATE"
}

ensure_build_deps() {
  log "Installing build dependencies (safe to re-run)"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential cmake git pkg-config curl ca-certificates python3 \
    nasm yasm \
    libjpeg-dev libpng-dev libtiff-dev libwebp-dev libfreetype6-dev \
    liblcms2-dev libxml2-dev libfftw3-dev zlib1g-dev liblzma-dev \
    libbrotli-dev libde265-dev libaom-dev libx265-dev \
    libexpat1-dev libinih-dev \
    libssl-dev libx264-dev libvpx-dev libmp3lame-dev libopus-dev \
    libvorbis-dev libass-dev libfreetype6-dev \
    autoconf automake libtool
}

write_env() {
  cat > "$PROFILE" <<EOF
# Added by mint-local-security.sh
export PATH="${BIN}:\$PATH"
EOF
  echo "${LIB}" > "$LDCONF"
  ldconfig
  log "PATH hook: $PROFILE"
  log "linker hook: $LDCONF"
}

installed_ver() { [[ -f $STATE/$1 ]] && cat "$STATE/$1" || echo none; }
record_ver()    { echo "$2" > "$STATE/$1"; }

# ---------- ImageMagick 7 ----------
build_imagemagick() {
  local have; have=$(installed_ver imagemagick)
  if [[ $have == "$IM_TAG" && -x $BIN/magick ]]; then
    log "ImageMagick $IM_TAG already installed"
    return
  fi
  log "Building ImageMagick $IM_TAG"
  rm -rf "$SRC/ImageMagick"
  git clone --depth 1 --branch "$IM_TAG" \
    https://github.com/ImageMagick/ImageMagick.git "$SRC/ImageMagick"
  (
    cd "$SRC/ImageMagick"
    ./configure --prefix="$PREFIX" --with-modules --disable-docs \
      --enable-shared --disable-static
    make -j"$(nproc)"
    make install
  )
  record_ver imagemagick "$IM_TAG"
  log "ImageMagick $($BIN/magick -version | head -1)"
}

# ---------- FFmpeg ----------
build_ffmpeg() {
  local have; have=$(installed_ver ffmpeg)
  if [[ $have == "$FF_TAG" && -x $BIN/ffmpeg ]]; then
    log "FFmpeg $FF_TAG already installed"
    return
  fi
  log "Building FFmpeg $FF_TAG"
  rm -rf "$SRC/FFmpeg"
  git clone --depth 1 --branch "$FF_TAG" \
    https://git.ffmpeg.org/ffmpeg.git "$SRC/FFmpeg"
  (
    cd "$SRC/FFmpeg"
    ./configure --prefix="$PREFIX" --enable-gpl --enable-shared \
      --disable-static --disable-doc \
      --enable-libx264 --enable-libx265 --enable-libvpx \
      --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libass
    make -j"$(nproc)"
    make install
  )
  record_ver ffmpeg "$FF_TAG"
  log "FFmpeg $($BIN/ffmpeg -version | head -1)"
}

# ---------- Exiv2 ----------
build_exiv2() {
  local have; have=$(installed_ver exiv2)
  if [[ $have == "$EX_TAG" && -x $BIN/exiv2 ]]; then
    log "Exiv2 $EX_TAG already installed"
    return
  fi
  log "Building Exiv2 $EX_TAG"
  rm -rf "$SRC/exiv2"
  git clone --depth 1 --branch "$EX_TAG" \
    https://github.com/Exiv2/exiv2.git "$SRC/exiv2"
  cmake -S "$SRC/exiv2" -B "$SRC/exiv2/build" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DEXIV2_ENABLE_VIDEO=ON \
    -DEXIV2_BUILD_SAMPLES=OFF
  cmake --build "$SRC/exiv2/build" -j"$(nproc)"
  cmake --install "$SRC/exiv2/build"
  record_ver exiv2 "$EX_TAG"
  log "Exiv2 $($BIN/exiv2 --version | head -1)"
}

# ---------- libheif ----------
build_libheif() {
  local have; have=$(installed_ver libheif)
  if [[ $have == "$HE_TAG" && -x $BIN/heif-dec ]]; then
    log "libheif $HE_TAG already installed"
    return
  fi
  log "Building libheif $HE_TAG"
  rm -rf "$SRC/libheif"
  git clone --depth 1 --branch "$HE_TAG" \
    https://github.com/strukturag/libheif.git "$SRC/libheif"
  cmake -S "$SRC/libheif" -B "$SRC/libheif/build" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_AOM_DECODER=ON -DWITH_AOM_ENCODER=ON \
    -DWITH_LIBDE265=ON -DWITH_X265=ON
  cmake --build "$SRC/libheif/build" -j"$(nproc)"
  cmake --install "$SRC/libheif/build"
  record_ver libheif "$HE_TAG"
  log "libheif tools in $BIN: $(ls "$BIN"/heif-* 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
}

# ---------- LibRaw ----------
build_libraw() {
  local have; have=$(installed_ver libraw)
  if [[ $have == "$LR_TAG" && -x $BIN/raw-identify ]]; then
    log "LibRaw $LR_TAG already installed"
    return
  fi
  log "Building LibRaw $LR_TAG"
  rm -rf "$SRC/LibRaw"
  git clone --depth 1 --branch "$LR_TAG" \
    https://github.com/LibRaw/LibRaw.git "$SRC/LibRaw"
  (
    cd "$SRC/LibRaw"
    autoreconf -fi
    ./configure --prefix="$PREFIX" --enable-shared --disable-static
    make -j"$(nproc)"
    make install
  )
  record_ver libraw "$LR_TAG"
  log "LibRaw tools: $(ls "$BIN"/raw-identify "$BIN"/simple_dcraw "$BIN"/unprocessed_raw 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
}

# ---------- apt freeze ----------
# Pin-Priority -1 makes apt refuse to install or upgrade these packages.
# apt-mark hold is the belt; the pin is the suspenders.
write_apt_pin() {
  {
    echo "# Written by mint-local-security.sh"
    echo "# Negative pin: apt will not install or upgrade these packages."
    echo "Package: ${APT_HOLD_PKGS[*]}"
    echo "Pin: release *"
    echo "Pin-Priority: -1"
  } > "$APTPREF"
  # apt preferences does not accept a space-separated Package list on one line
  # in every apt version. Write one stanza per package.
  {
    echo "# Written by mint-local-security.sh — do not edit by hand"
    for p in "${APT_HOLD_PKGS[@]}"; do
      printf 'Package: %s\nPin: release *\nPin-Priority: -1\n\n' "$p"
    done
  } > "$APTPREF"
}

hold_apt() {
  write_apt_pin
  apt-mark hold "${APT_HOLD_PKGS[@]}" >/dev/null || true
  log "Held + negatively pinned: ${APT_HOLD_PKGS[*]}"
}

unhold_apt() {
  rm -f "$APTPREF"
  apt-mark unhold "${APT_HOLD_PKGS[@]}" >/dev/null || true
  log "Released apt holds"
}

show_status() {
  echo "prefix: $PREFIX"
  printf '%-14s %-12s %s\n' PACKAGE PINNED INSTALLED
  printf '%-14s %-12s %s\n' imagemagick "$IM_TAG" "$(installed_ver imagemagick)"
  printf '%-14s %-12s %s\n' ffmpeg      "$FF_TAG" "$(installed_ver ffmpeg)"
  printf '%-14s %-12s %s\n' exiv2       "$EX_TAG" "$(installed_ver exiv2)"
  printf '%-14s %-12s %s\n' libheif     "$HE_TAG" "$(installed_ver libheif)"
  printf '%-14s %-12s %s\n' libraw      "$LR_TAG" "$(installed_ver libraw)"
  echo
  echo "binaries:"
  for b in magick ffmpeg ffprobe exiv2 heif-dec raw-identify simple_dcraw; do
    if [[ -x $BIN/$b ]]; then
      printf '  %s -> %s\n' "$b" "$BIN/$b"
    else
      printf '  %s MISSING\n' "$b"
    fi
  done
  echo
  echo "apt holds:"
  apt-mark showhold | grep -E "imagemagick|ffmpeg|^exiv2$|libheif|libraw" || echo "  (none matching)"
  echo
  echo "which (current shell PATH may not include $BIN until you re-login):"
  command -v magick ffmpeg exiv2 raw-identify 2>/dev/null || true
}

uninstall_all() {
  unhold_apt
  rm -f "$PROFILE" "$LDCONF"
  ldconfig
  rm -rf "$PREFIX"
  log "Removed $PREFIX and linker/PATH hooks"
}

cmd=${1:-install}

case $cmd in
  install)
    need_root
    ensure_dirs
    ensure_build_deps
    write_env
    build_imagemagick
    build_ffmpeg
    build_exiv2
    build_libheif
    build_libraw
    ldconfig
    hold_apt
    echo
    show_status
    echo
    echo "Open a new shell (or: source $PROFILE) so PATH picks up $BIN."
    echo "Bump the *_TAG variables at the top of this script and re-run to move forward."
    ;;
  status)
    show_status
    ;;
  hold)
    need_root
    hold_apt
    ;;
  unhold)
    need_root
    unhold_apt
    ;;
  uninstall)
    need_root
    uninstall_all
    ;;
  *)
    echo "Usage: $0 [install|status|hold|unhold|uninstall]" >&2
    exit 2
    ;;
esac
