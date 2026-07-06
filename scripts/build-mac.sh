#!/bin/bash
# macOS arm64 정적 FFmpeg 빌드 (GPL + LGPL 변형 동시 산출)
#
# 산출물:
#   dist/gpl/{ffmpeg,ffprobe}   — libx264 포함 (GenTube 출하용)
#   dist/lgpl/{ffmpeg,ffprobe}  — x264 제외, videotoolbox 인코더 (향후 B2B/App Store 대비, 출하 안 함)
#   dist/*/BUILDINFO.txt        — configure 전문 + -buildconf 출력 (컴플라이언스 킷)
#
# 요구: Xcode CLT + brew(nasm meson ninja pkg-config autoconf automake libtool)
# 실행: bash scripts/build-mac.sh   (사전: bash scripts/fetch-sources.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
source versions.env

WORK="$ROOT/work"
PREFIX="$WORK/prefix"
SRC="$ROOT/sources"
JOBS=$(sysctl -n hw.ncpu)
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export CFLAGS="-I$PREFIX/include -O2"
export LDFLAGS="-L$PREFIX/lib"

mkdir -p "$WORK" "$ROOT/dist/gpl" "$ROOT/dist/lgpl"
cd "$WORK"

unpack() { # <타르볼> <디렉토리명>
    [ -d "$2" ] && return 0
    echo "== unpack $1 =="
    tar xf "$SRC/$1"
}

echo "===== 1) expat ====="
unpack "expat-${EXPAT_VERSION}.tar.xz" "expat-${EXPAT_VERSION}"
( cd "expat-${EXPAT_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --without-docbook -q && make -j"$JOBS" -s && make install -s )

echo "===== 2) freetype (1차: harfbuzz 없이) ====="
unpack "freetype-${FREETYPE_VERSION}.tar.xz" "freetype-${FREETYPE_VERSION}"
( cd "freetype-${FREETYPE_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --with-harfbuzz=no -q && make -j"$JOBS" -s && make install -s )

echo "===== 3) fribidi ====="
unpack "fribidi-${FRIBIDI_VERSION}.tar.xz" "fribidi-${FRIBIDI_VERSION}"
( cd "fribidi-${FRIBIDI_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static -q && make -j"$JOBS" -s && make install -s )

echo "===== 4) harfbuzz (meson) ====="
unpack "harfbuzz-${HARFBUZZ_VERSION}.tar.xz" "harfbuzz-${HARFBUZZ_VERSION}"
( cd "harfbuzz-${HARFBUZZ_VERSION}" && meson setup build --prefix="$PREFIX" --default-library=static -Dfreetype=enabled -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled >/dev/null && ninja -C build >/dev/null && ninja -C build install >/dev/null )

echo "===== 5) fontconfig ====="
unpack "fontconfig-${FONTCONFIG_VERSION}.tar.xz" "fontconfig-${FONTCONFIG_VERSION}"
( cd "fontconfig-${FONTCONFIG_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-docs --sysconfdir=/usr/local/etc -q && make -j"$JOBS" -s && make install -s )

echo "===== 6) libass ====="
unpack "libass-${LIBASS_VERSION}.tar.xz" "libass-${LIBASS_VERSION}"
( cd "libass-${LIBASS_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static -q && make -j"$JOBS" -s && make install -s )

echo "===== 7) x264 (GPL) ====="
unpack "x264-${X264_BRANCH}.tar.bz2" "x264-${X264_BRANCH}"
( cd "x264-${X264_BRANCH}" && ./configure --prefix="$PREFIX" --enable-static --disable-cli --enable-pic >/dev/null && make -j"$JOBS" -s && make install -s )

build_ffmpeg() { # <변형: gpl|lgpl>
    local variant=$1
    local dir="ffmpeg-${FFMPEG_VERSION}-${variant}"
    echo "===== 8-${variant}) FFmpeg ${FFMPEG_VERSION} (${variant}) ====="
    rm -rf "$dir" && mkdir "$dir"
    tar xf "$SRC/ffmpeg-${FFMPEG_VERSION}.tar.xz" -C "$dir" --strip-components=1
    cd "$dir"
    local common=(
        --prefix="$WORK/out-${variant}"
        --pkg-config-flags="--static"
        --extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib"
        --disable-autodetect
        --enable-libass --enable-libfreetype --enable-libharfbuzz --enable-libfribidi --enable-fontconfig
        --enable-zlib --enable-bzlib --enable-iconv
        --enable-videotoolbox
        --disable-ffplay --disable-doc --disable-debug
        --cc=clang
    )
    if [ "$variant" = "gpl" ]; then
        ./configure "${common[@]}" --enable-gpl --enable-libx264 >/dev/null
    else
        ./configure "${common[@]}" >/dev/null
    fi
    make -j"$JOBS" -s
    cp ffmpeg ffprobe "$ROOT/dist/${variant}/"
    {
        echo "== gentube-ffmpeg BUILDINFO (${variant}) =="
        echo "빌드일: $(date -u +%Y-%m-%dT%H:%M:%SZ) / 호스트: macOS $(sw_vers -productVersion) arm64"
        echo "== configure =="
        "./ffmpeg" -hide_banner -buildconf 2>&1 | head -60
        echo "== version =="
        "./ffmpeg" -version 2>&1 | head -4
    } > "$ROOT/dist/${variant}/BUILDINFO.txt"
    cd "$WORK"
}

build_ffmpeg gpl
build_ffmpeg lgpl

echo ""
echo "===== 산출물 ====="
ls -lh "$ROOT"/dist/gpl/ "$ROOT"/dist/lgpl/
echo ""
echo "다음: 스모크 테스트 → dist/* + sources/* + LICENSES/*를 GitHub Release에 첨부"
