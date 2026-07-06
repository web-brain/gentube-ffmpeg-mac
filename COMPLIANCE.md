# GPL 컴플라이언스 가이드 (GenTube FFmpeg 빌드)

## 왜 이 리포가 존재하나

GenTube 데스크탑 앱은 FFmpeg를 **별도 실행 파일**로 번들하고 subprocess로 호출한다(링크하지 않음 = mere aggregation — 앱 자체 코드는 GPL 적용 대상 아님).
그러나 **GPL 바이너리를 배포하는 자는 그 바이너리의 대응 소스(corresponding source)를 수령자에게 제공할 의무**가 있다 (GPLv2 §3 / GPLv3 §6).

이 리포는 그 의무를 이행한다:
- **배포하는 정확히 그 빌드**의 소스 타르볼 전체(FFmpeg + 정적 링크된 모든 라이브러리) — `sources/` + 릴리스 자산
- **빌드 스크립트와 configure 설정** — `scripts/` + 산출물의 `BUILDINFO.txt`
- **라이선스 전문** — `LICENSES/GPL-2.0.txt`, `LICENSES/GPL-3.0.txt`

## 릴리스 체크리스트 (앱 릴리스마다)

1. `versions.env` 확인/갱신 → `bash scripts/fetch-sources.sh` (MANIFEST 재생성)
2. 빌드 (GitHub Actions `build-mac-arm64` 또는 로컬 `bash scripts/build-mac.sh`)
3. 스모크 테스트 통과 확인 (자막 번인 + libx264)
4. `v*` 태그 푸시 → 릴리스에 **바이너리 + 소스 타르볼 + MANIFEST + GPL 전문** 자동 첨부
5. GenTube 앱의 `resources/ffmpeg-mac/` 교체 → 앱 전체 E2E (디코더 누락 회귀 검증)
6. GenTube 릴리스 노트/고지 화면의 소스 링크가 이 릴리스를 가리키는지 확인
7. **릴리스 삭제 금지** — 소스 제공 의무는 해당 바이너리 배포 기간 + 3년 이상 유지

## 앱 내 고지 문안 (GenTube 오픈소스 고지 화면용)

> 이 소프트웨어는 GNU General Public License(GPL)로 라이선스된 FFmpeg(https://ffmpeg.org) 및 x264 라이브러리를 포함한 빌드를 별도 실행 파일로 사용합니다. FFmpeg 바이너리는 본 애플리케이션에 링크되지 않고 독립 프로세스로 실행됩니다.
> 배포된 바이너리의 완전한 대응 소스 코드(정확한 소스 아카이브, 빌드 스크립트, 빌드 설정 포함)는 다음에서 제공됩니다:
> **https://github.com/<OWNER>/gentube-ffmpeg/releases**
>
> This software uses builds of FFmpeg (https://ffmpeg.org) and the x264 library, licensed under the GNU General Public License, executed as separate processes (not linked into this application). The complete corresponding source code — including exact source archives, build scripts, and configuration — is available at the URL above.

## 변형 정책

| 변형 | 구성 | 용도 |
|---|---|---|
| **gpl** | `--enable-gpl --enable-libx264` + libass 스택 | **GenTube 출하용** (x264 화질) |
| **lgpl** | GPL 컴포넌트 제거, `h264_videotoolbox` | 빌드만 유지, 미출하 — B2B 조달/Mac App Store 필요 시 전환용 |

미사용 GPL 컴포넌트(libx265/vidstab/xvid 등)는 **빌드에서 제외** — 소스 제공 범위·바이너리 크기 축소 (라이선스 등급은 libx264로 인해 gpl 변형은 여전히 GPL).

## 참고 사실 (조사 근거, 2026-07)

- 기존 서드파티 프리빌트(mac: osxexperts 계열 "educational purposes only" / win: gyan.dev 빌드 스크립트 비공개)는 **대응 소스 세트를 재구성할 수 없어** 상용 재배포 컴플라이언스에 부적합 → 자가 빌드로 교체
- macOS 시스템 라이브러리(zlib/bzip2/iconv/libSystem)는 GPL의 System Library 예외에 해당
- Windows 빌드 계획: [WINDOWS.md](WINDOWS.md)
