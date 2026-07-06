#!/bin/bash
# 소스 타르볼 확보 + MANIFEST 생성 — GPL "corresponding source" 의무 이행의 핵심.
# 배포하는 바이너리를 만든 정확한 소스 세트를 sources/에 보관하고, 릴리스 자산으로 첨부한다.
# bash로 실행할 것.
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
mkdir -p sources
cd sources

fetch() { # <파일명> <URL>
    local file=$1 url=$2
    if [ -f "$file" ]; then echo "  [skip] $file (이미 존재)"; return; fi
    echo "  [get ] $file"
    curl -fsSL --retry 3 -o "$file" "$url"
}

echo "== 소스 타르볼 다운로드 =="
fetch "ffmpeg-${FFMPEG_VERSION}.tar.xz"        "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
fetch "x264-${X264_BRANCH}.tar.bz2"            "https://code.videolan.org/videolan/x264/-/archive/${X264_BRANCH}/x264-${X264_BRANCH}.tar.bz2"
fetch "lame-${LAME_VERSION}.tar.gz"           "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz"
fetch "expat-${EXPAT_VERSION}.tar.xz"          "https://github.com/libexpat/libexpat/releases/download/R_$(echo "$EXPAT_VERSION" | tr . _)/expat-${EXPAT_VERSION}.tar.xz"
fetch "freetype-${FREETYPE_VERSION}.tar.xz"    "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz"
fetch "fribidi-${FRIBIDI_VERSION}.tar.xz"      "https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz"
fetch "harfbuzz-${HARFBUZZ_VERSION}.tar.xz"    "https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
fetch "fontconfig-${FONTCONFIG_VERSION}.tar.xz" "https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz"
fetch "libunibreak-${LIBUNIBREAK_VERSION}.tar.gz" "https://github.com/adah1972/libunibreak/releases/download/libunibreak_$(echo "$LIBUNIBREAK_VERSION" | tr . _)/libunibreak-${LIBUNIBREAK_VERSION}.tar.gz"
fetch "libass-${LIBASS_VERSION}.tar.xz"        "https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz"

echo ""
echo "== MANIFEST 생성 (sha256 + 크기 + 확보일) =="
{
    echo "# gentube-ffmpeg corresponding source manifest"
    echo "# 확보일: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# versions.env: FFMPEG=${FFMPEG_VERSION} X264=${X264_BRANCH} LAME=${LAME_VERSION} EXPAT=${EXPAT_VERSION} FREETYPE=${FREETYPE_VERSION} FRIBIDI=${FRIBIDI_VERSION} HARFBUZZ=${HARFBUZZ_VERSION} FONTCONFIG=${FONTCONFIG_VERSION} LIBUNIBREAK=${LIBUNIBREAK_VERSION} LIBASS=${LIBASS_VERSION}"
    echo ""
    shasum -a 256 *.tar.* 2>/dev/null || sha256sum *.tar.*
    echo ""
    ls -l *.tar.* | awk '{print $5, $9}'
} > MANIFEST.txt
cat MANIFEST.txt
echo ""
echo "완료. sources/ 전체를 릴리스 자산으로 첨부할 것."
