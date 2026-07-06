# Windows x64 빌드 계획 (미구현 — 다음 마일스톤)

현재 GenTube의 `resources/ffmpeg-win/`은 gyan.dev 8.0.1 essentials(GPLv3)를 사용 중이다.
gyan.dev는 빌드 스크립트가 비공개이고 정적 링크된 라이브러리들의 릴리스별 소스 아카이브를 제공하지 않아,
**대응 소스 제공 의무를 자력으로 이행할 수 없다** → 교체 필요.

## 채택 방안: BtbN/FFmpeg-Builds 포크

[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)는:
- 빌드 스크립트 전체 공개(MIT), 의존성이 `scripts.d/*.sh`에 **커밋 단위로 핀 고정** (예: `50-x264.sh`의 `SCRIPT_COMMIT`)
- 퍼블릭 GitHub Actions 빌드, win64 gpl/lgpl 변형 지원

## 작업 순서

1. BtbN 포크 → `scripts.d/`에서 GenTube가 쓰지 않는 라이브러리 스크립트 제거 (유지: x264 + libass 스택[freetype/fribidi/harfbuzz/fontconfig] + 기본 코덱)
2. 본인 Actions로 win64 gpl(+lgpl) 빌드
3. 빌드 시점에 각 `SCRIPT_COMMIT` 소스를 tar로 아카이브 → 이 리포 릴리스에 첨부 (mac과 동일한 컴플라이언스 킷 형태)
4. GenTube `resources/ffmpeg-win/` 교체 → 전체 E2E
5. 교체 전까지의 잠정 조치: 현 gyan 빌드에 대해 GPLv3 텍스트 + gyan 소스 링크(FFmpeg 커밋)를 고지 — 완전하지 않으므로 조속히 교체

## 참고

- Windows는 hw 인코더 폴백이 다양(NVENC/QSV/AMF/h264_mf) — lgpl 변형 전환 시 유리
- NSIS 인스톨러에 LICENSES/ 동봉은 GenTube 쪽 T7(고지 페이지) 작업에서 처리
