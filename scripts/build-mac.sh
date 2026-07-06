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
# --without-png/--without-brotli: CI 러너 Homebrew의 libpng16/brotli 동적 링크 누출 차단
# (자막은 벡터 글리프 렌더 — 임베디드 PNG 비트맵/WOFF2 브로틀리 불필요). 정적 배포 필수.
( cd "freetype-${FREETYPE_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --with-harfbuzz=no --without-png --without-brotli -q && make -j"$JOBS" -s && make install -s )

echo "===== 3) fribidi ====="
unpack "fribidi-${FRIBIDI_VERSION}.tar.xz" "fribidi-${FRIBIDI_VERSION}"
( cd "fribidi-${FRIBIDI_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static -q && make -j"$JOBS" -s && make install -s )

echo "===== 4) harfbuzz (meson) ====="
unpack "harfbuzz-${HARFBUZZ_VERSION}.tar.xz" "harfbuzz-${HARFBUZZ_VERSION}"
# glib/gobject/icu/cairo disabled: CI 러너 Homebrew의 glib(→pcre2/gettext) 동적 링크 누출 차단.
# harfbuzz 내장 유니코드(ucdn)로 libass shaping 충분 — glib 불필요. 정적 배포 필수.
( cd "harfbuzz-${HARFBUZZ_VERSION}" && meson setup build --prefix="$PREFIX" --default-library=static -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dicu=disabled -Dcairo=disabled -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled >/dev/null && ninja -C build >/dev/null && ninja -C build install >/dev/null )

echo "===== 5) fontconfig ====="
unpack "fontconfig-${FONTCONFIG_VERSION}.tar.xz" "fontconfig-${FONTCONFIG_VERSION}"
# sysconfdir는 prefix 내부로 — CI 권한 문제 회피 + 시스템 오염 방지 (gentube는 subtitles에 fontsdir를 명시 전달하므로 시스템 설정 경로 불필요)
# --disable-nls: gettext(libintl) 동적 링크 누출 차단 (자막 렌더에 번역메시지 불필요)
( cd "fontconfig-${FONTCONFIG_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-docs --disable-nls --sysconfdir="$PREFIX/etc" -q && make -j"$JOBS" -s && make install -s )

echo "===== 6) libunibreak (CJK 자동 줄바꿈 — libass ASS_FEATURE_WRAP_UNICODE 활성화) ====="
unpack "libunibreak-${LIBUNIBREAK_VERSION}.tar.gz" "libunibreak-${LIBUNIBREAK_VERSION}"
( cd "libunibreak-${LIBUNIBREAK_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static -q && make -j"$JOBS" -s && make install -s )

echo "===== 7) libass ====="
unpack "libass-${LIBASS_VERSION}.tar.xz" "libass-${LIBASS_VERSION}"
( cd "libass-${LIBASS_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static -q && make -j"$JOBS" -s && make install -s )

echo "===== 8) LAME (libmp3lame — LGPL, gentube TTS의 pydub mp3 export 의존) ====="
unpack "lame-${LAME_VERSION}.tar.gz" "lame-${LAME_VERSION}"
# --disable-frontend: lame CLI 미빌드(libmp3lame만). --disable-nls: gettext 누출 차단
( cd "lame-${LAME_VERSION}" && ./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-frontend --disable-nls -q && make -j"$JOBS" -s && make install -s )

echo "===== 9) x264 (GPL) ====="
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
        --enable-libmp3lame
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

# ═══════════════════════════════════════════════════════════════
# 자가 검증 — 실패 시 빌드 FAIL (배포 불가 결함이 다시 새어나가지 않도록)
# 2026-07 적대적 검증에서 발견한 2개 결함(Homebrew dylib 누출 / libmp3lame 누락)의 재발 방지.
# ═══════════════════════════════════════════════════════════════
echo ""
echo "===== 자가 검증 ====="
FAIL=0
for bin in "$ROOT"/dist/gpl/ffmpeg "$ROOT"/dist/gpl/ffprobe "$ROOT"/dist/lgpl/ffmpeg "$ROOT"/dist/lgpl/ffprobe; do
    # (1) 정적 링크: 시스템(/usr/lib, /System) 외 동적 의존이 있으면 FAIL
    LEAK=$(otool -L "$bin" | tail -n +2 | grep -vE '^\s+(/usr/lib/|/System/)' || true)
    if [ -n "$LEAK" ]; then
        echo "❌ [$bin] 비시스템 dylib 의존 발견 (배포 불가):"; echo "$LEAK"; FAIL=1
    fi
done
# (2) gentube 필수 인코더 존재 확인 (mp3=libmp3lame 포함)
for enc in libx264 aac pcm_s16le libmp3lame; do
    if ! "$ROOT"/dist/gpl/ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw "$enc"; then
        echo "❌ 필수 인코더 누락: $enc"; FAIL=1
    fi
done
# lgpl 변형은 x264 없이(비디오는 videotoolbox), mp3/aac는 있어야 함
for enc in aac pcm_s16le libmp3lame; do
    "$ROOT"/dist/lgpl/ffmpeg -hide_banner -encoders 2>/dev/null | grep -qw "$enc" || { echo "❌ lgpl 인코더 누락: $enc"; FAIL=1; }
done
[ "$FAIL" -eq 0 ] && echo "✅ 자가 검증 통과 (정적 링크 + 필수 인코더)" || { echo "빌드 실패 — 위 결함 수정 필요"; exit 1; }

echo ""
echo "===== 산출물 ====="
ls -lh "$ROOT"/dist/gpl/ "$ROOT"/dist/lgpl/
echo ""
echo "다음: 스모크 테스트 → dist/* + sources/* + LICENSES/*를 GitHub Release에 첨부"
