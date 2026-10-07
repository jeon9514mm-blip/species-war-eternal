# Windows 전신 프레임 사냥 검수

이전 클라우드 작업의 코드·이미지·메타데이터·검수 자료를 전달 브랜치 `codex/hunt-frame-handoff-2026-10-07`, 커밋 `284f5afb454607535c9b145b07f4ef680d3f1503`에서 가져왔다. 이번 기본 브랜치 업데이트에는 그 작업과 아래 Windows 검수·30fps 회수 동작 보완을 함께 포함한다.

Godot `4.7.2.stable.official.ed1daf0bf`, Windows, NVIDIA GeForce GTX 1050, Mobile Vulkan에서 촬영한다. 개인 플레이 저장 대신 임시 사용자 경로를 사용한다.

## 영상의 의미

- [자연 사냥 영상](captures/actual-hunting.mp4): 기본 `PortraitMain.tscn`, 레벨 1 레온하르트, 기존 능력치·전투 로직, 30fps·12초. 첫 8초는 기본 카메라, 마지막 4초는 자세 확인용 확대 카메라다. 레온하르트의 공격·이동·피격과 고블린의 이동·사망을 포함한다. 고블린은 공격하기 전에 쓰러져 곤봉 공격 검수는 아래 별도 장면에서 수행한다.
- [1대1 전투 동작 검수](captures/combat-duel-inspection.mp4): 실제 생성된 초원 고블린 한 마리와 레온하르트만 배치한 30fps·6초 검수 장면이다. 능력치를 변경하지 않으며 기본 공격만 사용한다. 시작 위치·공격 대기시간·카메라를 설정하고 3초에 전투를 재설정하여 좌우 반전을 확인한다. 일반 사냥터에서 자연 발생한 전투 영상과 구분한다.
- [자연 사냥 기록](captures/actual-hunt.json), [1대1 전투 기록](captures/combat-duel-inspection.json)에는 각 프레임의 행동·전신 그림 번호·공격 시퀀스·체력을 기록한다. 1대1 기록은 설정한 검수 조건과 초기 능력치도 포함한다.

## 검증

- [Windows 회귀 결과](windows-tests.json): 이전 코드 전체 477/477개 Godot 구문 검사, `HuntFramePilotSmokeTest`·`HuntAttackQualitySmokeTest`·`HuntCoordinationSmokeTest` 3/3개 통과.
- 30fps에서 마지막 회수 자세가 건너뛰어지던 문제를 수정했다. 회수 구간의 표시 경계만 조정했고 실제 타격 경계 `.44`는 유지했다. [최종 전투 회귀](final-regression-tests.json)는 3/3개·총 251항목을 통과했으며, 새 검사에서 실제 30fps 시간 간격으로 공격 8개 자세가 모두 재생되는지 확인한다. 최종 집중 검사는 이전 전체 구문 검사 후 `--skip-syntax`로 실행했다.
- [변경한 GDScript 파서 검사](final-changed-parser.json)는 카탈로그·회귀 검사·자연 사냥 촬영·1대1 촬영의 최종 소스 4개를 다시 확인한다. 새 촬영 도구의 수동 프레임 처리에서는 2D 원본 타이머를 다시 멈춰 작은 원본 그림이 중복 표시되지 않도록 한다. 종료할 때 진행 중인 피격 효과와 콜백을 정리할 시간을 둔다.
- [사냥 요약](capture-summary.json)에는 실제 재생한 행동·그림 번호·카메라 구간·렌더 오류 여부를 기록한다.
- [1대1 검수 요약](duel-summary.json): 두 캐릭터 모두 양쪽 방향에서 공격 8개 자세를 재생했다. 체력이 줄어든 실제 타격 8건 모두 공격 그림 3번·타격 구간 `.44`와 일치했다. 자연 사냥과 1대1 촬영의 최종 종료 로그에는 렌더·스크립트·리소스 누수 오류가 없었다.
- [최종 정적·Python 검사](final-static-python.json): GDScript 478개·회귀 진입점 227개 정적 리소스 검사, 현재 아키텍처 검사, Python 도구 검사 50/50개 통과.

현재 적용은 레온하르트와 초원 고블린 두 캐릭터의 시범 구현이다. 고블린의 신규 보행 네 자세, 스킬·궁극기 전용 신규 전신 그림, 다른 캐릭터 확장과 Android 실기기 성능 검수는 남아 있다.

## 재현

저장소 루트에서 엔진과 FFmpeg 경로를 지정한다. Windows Python은 `-X utf8`로 실행한다.

```sh
python -X utf8 tools/render_hunt_frames.py --godot /path/to/godot --ffmpeg /path/to/ffmpeg --output checks/hunt-frame-windows-2026-10-07 --live
python -X utf8 tools/render_hunt_frames.py --godot /path/to/godot --ffmpeg /path/to/ffmpeg --output checks/hunt-frame-windows-2026-10-07 --duel
```

원시 캡처 프레임은 임시 경로에서 영상으로 변환한 뒤 제거한다. 로그는 `.gitignore`에 따라 로컬에만 남는다.
