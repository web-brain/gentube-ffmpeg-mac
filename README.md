# gentube-ffmpeg

[GenTube](https://github.com/) 데스크탑 앱에 번들되는 FFmpeg 바이너리의 **재현 가능 빌드 + GPL 컴플라이언스 킷**.

> 이 리포는 **퍼블릭**이어야 한다 — 존재 이유가 "GPL 바이너리 수령자 누구나 대응 소스를 받을 수 있게 하는 것"이므로.

## 구조

```
versions.env                  # 핀 고정 버전 (단일 원천)
scripts/fetch-sources.sh      # 소스 타르볼 확보 + MANIFEST(sha256) 생성
scripts/build-mac.sh          # macOS arm64 정적 빌드 (gpl + lgpl 변형)
.github/workflows/build-mac.yml  # CI 빌드 + 스모크 테스트 + 릴리스 자산 첨부
LICENSES/                     # GPL-2.0 / GPL-3.0 전문
COMPLIANCE.md                 # 의무 체크리스트 + 앱 내 고지 문안
WINDOWS.md                    # Windows 빌드 계획 (BtbN 포크, 다음 마일스톤)
```

## 빌드 구성 (최소화 원칙)

GenTube가 실제 사용하는 컴포넌트만 포함 (코드 실측 기반):
- 인코더: **libx264**(GPL 트리거, 유일), aac(native), pcm
- 자막 번인: **libass** (+freetype/harfbuzz/fribidi/fontconfig)
- 필터: subtitles/scale/crop/pad/zoompan/blend/amix/loudnorm/noise 등 — 전부 내장(외부 의존성 0)
- `--disable-autodetect`로 우발적 시스템 라이브러리 링크 차단

x265/vidstab/xvid 등 미사용 GPL 컴포넌트는 제외 (기존 서드파티 빌드 대비 바이너리·소스 제공 범위 축소).

## 릴리스와 GenTube 버전 매핑

| 이 리포 릴리스 | FFmpeg | GenTube 버전 | 비고 |
|---|---|---|---|
| (첫 릴리스 예정) | 8.1 | 2.x | mac arm64 |

## 사용법

```bash
bash scripts/fetch-sources.sh   # 소스 확보 (sources/MANIFEST.txt 생성)
bash scripts/build-mac.sh       # 빌드 → dist/gpl/, dist/lgpl/
```

CI: Actions 탭에서 `build-mac-arm64` 수동 실행, 또는 `v*` 태그 푸시 시 릴리스 자동 생성.

## 라이선스

- 이 리포의 스크립트/문서: MIT
- 산출 바이너리: **GPL-2.0-or-later** (gpl 변형, libx264 포함) / LGPL-2.1-or-later (lgpl 변형)
- 각 소스 타르볼은 각자의 라이선스를 따름 — 전문은 릴리스 자산과 `LICENSES/` 참조
