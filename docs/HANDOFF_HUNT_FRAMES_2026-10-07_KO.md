# 전신 프레임 애니메이션 작업 인수인계

## 전달 상태와 작업 범위

사용자가 제작 중지를 요청한 뒤, 현재 작업을 별도 GitHub 브랜치로 전달하도록 승인했다. 이번 전달은 기존 작업 보존이며 새 제작·기능 확장·기본 브랜치 병합을 포함하지 않는다.

- 저장소: https://github.com/jeon9514mm-blip/species-war-eternal
- 전달 브랜치: `codex/hunt-frame-handoff-2026-10-07`
- 기반 커밋: `14bf17ebaf6599d38a3b6a837a8da727963eb981`
- 기본 브랜치: `jeon9514mm-blip/species-war-eternal` — 이번 전달에서 수정하지 않음
- 로컬 작업 경로: `/workspace/species-war-cleanup`
- 엔진: Godot `4.7.2.stable.official.ed1daf0bf`
- 실제 시작 씬: `scenes/PortraitMain.tscn`

새 채팅에서는 이 브랜치를 가져와 이 문서를 먼저 읽는다. 새 제작은 사용자가 재개를 요청할 때 시작한다. 가로 화면, 기존 사냥·데미지·보상·저장 규칙을 유지한다.

## 사용자가 선택한 방향

레온하르트와 초원 고블린부터 움직임을 개선하던 중 사용자가 목·손·무기 연결과 관절 조립 방식의 부자연스러움을 지적했다. 해당 방식의 실행 연결은 되돌렸고, **완성된 전신 그림을 프레임마다 바꿔 재생하는 방식**으로 전환했다. 거절한 관절 방식으로 돌아가지 않는다.

이번 버전은 레온하르트와 이름이 정확히 `초원 고블린`인 몬스터만 대상으로 하는 개발 중 시범 구현이다. 나머지 영웅·몬스터와 레이드는 기존 렌더링을 사용한다. 전체 영웅의 16개 동작 제작이 완료된 상태가 아니다.

## 포함한 코드와 애셋

- `scripts/art/HuntFrameCatalog.gd`: 프레임 영역·발 위치·알파 외곽선 검증과 인스턴스 수명에 맞춘 메타데이터 캐시.
- `scripts/art/HuntFrameTimeline.gd`: 실제 공격 준비·공격 확정 이벤트·피격·사망·일시 정지에 맞춘 표시 시계. 데미지 계산이나 보상 처리를 하지 않는다.
- `scripts/art/HuntFramePilot.gd`: 전신 프레임 하나를 카메라 방향으로 표시한다. 부위별 조립·골격·머리 회전·신체 찌그러뜨림 없이 좌우 반전과 발 기준 정렬을 사용한다. 외곽 메시의 역할은 이웃 프레임 그림을 잘라내는 것이다.
- `scripts/app/Main.gd`: 실제 확정 공격과 양의 실제 피해를 표시 코드에 알리는 이벤트 추가.
- `scripts/maps3d/Battlefield3DView.gd`: 해당 두 캐릭터의 시범 렌더러 연결, 기존 표시와의 중복 방지, 이벤트 전달 및 대체 렌더링.
- `assets/art-direction/hunt-frame-pilot/`: 레온하르트 공격 8프레임·이동/대기/피격/사망 8프레임, 고블린 공격 8프레임 원본 PNG와 분석·실행 JSON 및 Godot 원본 import 메타데이터.
- 고블린 이동은 저장소에 이미 있는 `assets/art-direction/pilot-01/monsters/meadow-goblin.png`와 기존 메타데이터를 재사용한다. 네 단계 재생에 중립 자세를 섞으며, 서로 다른 신규 보행 그림 네 장을 제작한 것은 아니다.
- `tests/regression/HuntFramePilotSmokeTest.gd`: 실제 공격·피격·사망·재생 정지·좌우 반전·대체 렌더링과 표시 처리의 게임 상태 독립성 검사.
- `tools/measure_hunt_frame_atlas.py`, `tools/review_hunt_frames.gd`, `tools/capture_hunt_frames.gd`, `tools/render_hunt_frames.py`: 읽기 전용 이미지 분석, 전신 자세 검수, 실제 사냥 캡처 및 임시 저장 경로를 이용한 렌더 도구.

## 검수 자료

`checks/hunt-frame-pilot-2026-10-07/captures/`에 공격 8장·이동 등 8장·반전 1장과 `whole-pose-review.json`, `whole-pose-animation.mp4`를 보존했다. **이 영상은 확대된 자세 검수용 느린 재생이며 실제 사냥 녹화가 아니다.** 전신의 목·팔 연결과 공격 자세를 확인할 때 사용한다.

거절한 관절 조립 소스 중 보존할 코드·이미지·JSON은 같은 검수 폴더의 `rejected-cutout-source/`에 있다. 코드와 UID는 `.source` 확장자로 보관해 실행 및 소스 검사 대상에서 제외했다. 원래 파일 이름과 SHA-256은 해당 `manifest.json`에 기록했다. 실행 코드에서 참조하지 않는다.

개인 플레이 저장, 자격증명, `.godot` 등 캐시, 로그, 임시 원시 캡처 프레임은 전달에 포함하지 않는다. PNG의 `.import`는 Godot 원본 리소스 설정이며 캐시가 아니다.

## 검증 결과

전달 직전 마지막 인스턴스 캐시 수정까지 포함한 코드에서 다음을 통과했다.

- Godot 집중 회귀 3/3: `HuntFramePilotSmokeTest`, `HuntAttackQualitySmokeTest`, `HuntCoordinationSmokeTest`. 결과는 `handoff-tests.json`.
- 정적 검사: GDScript 477개, 회귀 진입점 227개, 리소스·경로 검사 통과.
- 현재 아키텍처 검사 통과: 서비스 모듈 9개, Main 줄 수 5684.
- Python 도구 테스트 50/50 및 `git diff --check` 통과. 결과는 `handoff-static-python.json`.
- Mobile Vulkan 소프트웨어 GPU에서 전신 자세 PNG·MP4 렌더 완료. 정적 캐시를 인스턴스 캐시로 바꾼 뒤 재실행에서는 종료 시 리소스 누수 오류가 없었다.

미완료:

- 실제 사냥 영상 캡처는 사용자의 중지 요청에 따라 SIGINT로 종료했다. 완성 영상·실제 사냥 시각 검수를 통과했다고 간주하지 않는다.
- 전체 GDScript의 Godot 파서 검사와 전체 역사적 회귀 테스트는 이번 최종 전달 검사에서 실행하지 않았다. 집중 회귀의 `--skip-syntax`는 JSON에 명시되어 있다.
- 실제 Android 성능·입력·가독성 검사는 하지 않았다. 소프트웨어 GPU 검수는 모바일 기기 성능 보증이 아니다.
- 스킬·궁극기·가드 전용 신규 전신 애니메이션은 아직 없다. 해당 동작에서 중립 가드 프레임과 기존 전투 효과를 사용한다.

이전 실패와 수정:

- 초기에 전신 자세 GPU 검수 종료 시 정적 캐시 관련 리소스 누수가 발견되어 인스턴스 캐시로 수정했고, 재렌더에 성공했다.
- Python 테스트를 존재하지 않는 `tests/python` 경로로 실행한 초기 명령은 실패했다. 올바른 `tools` 경로에서 50개 테스트를 다시 실행해 모두 통과했다.
- 실제 사냥 캡처 종료는 사용자의 중지 요청에 따른 중단이며 검증 성공이나 게임 결함 판정으로 기록하지 않는다.

## 재개할 때의 다음 순서

1. 브랜치와 위 검수 PNG·MP4를 확인하고 사용자가 재개를 요청했는지 확인한다.
2. 실제 기본 사냥 화면의 두 캐릭터 동작·발 정렬·공격 타이밍을 녹화하고 시각 검수한다. 제작 도구는 임시 사용자 경로를 이용하므로 실제 플레이 저장을 덮어쓰지 않는다.
3. 필요할 때 전체 Godot 파서 검사와 해당 기능·레이드 회귀를 수행한다. 현재 녹화 미완료를 먼저 해소하며 무관한 대규모 변경을 시작하지 않는다.
4. 시각 결과를 사용자에게 보여주고 재개 승인 범위에 맞춰 개선한다. 기본 브랜치 병합은 이 전달 요청에 포함되지 않는다.

전달 직전 사용한 검사 명령:

```bash
python tools/static_validate.py
python tools/validate_v83_architecture.py
python -m unittest discover -s tools -p 'test_*.py' -q
python tools/run_tests.py --godot /workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --jobs 2 --skip-syntax --tests HuntFramePilotSmokeTest.gd HuntAttackQualitySmokeTest.gd HuntCoordinationSmokeTest.gd --output checks/hunt-frame-pilot-2026-10-07/handoff-tests.json
```
