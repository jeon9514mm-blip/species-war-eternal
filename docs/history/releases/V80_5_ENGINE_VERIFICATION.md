# v80-5 Godot 실제 엔진 검증·오류 수정

검증 시각: 2026-10-01T01:34:22+09:00

## 결론

사용자가 올린 **Godot 4.7.2.stable.official.ed1daf0bf Linux x86_64** 실행 파일로 실제 엔진을 실행했다. 최종 리소스 임포트, 전체 GDScript **261/261개 엔진 검사**, 집중 런타임 **16/16개 스크립트**가 통과했다. 이 단계는 v80-4에 대한 실행 검증과 오류 수정이며 **v81~v85를 구현한 것이 아니다.**

## 정확한 기준본

v79 분할 압축을 CRC 검사 후 복원하고 마지막 v80-4 누적 패치만 적용했다. 같은 이름의 이전 다른 경로 패치와 섞지 않았다.

- 입력 v80-4 패치 SHA-256: `49ab7693a36cd7da8b2e983230a06a1c017b09fc77f4387e83a4f118f7673872`
- 사용자 엔진 ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`
- 엔진 ZIP CRC 검사: 오류 없음. 실제 실행 버전: `4.7.2.stable.official.ed1daf0bf`
- 초기 임포트는 실패했고, 오류를 수정한 뒤 별도 새 사본으로 최종 임포트와 핵심 실행 검사를 다시 수행했다. 종료 코드 0이어도 ERROR/SCRIPT ERROR가 있으면 실패로 판정했다.

## 수정 사항

### 1. 시작 화면을 막던 Main.gd 오류

v79에도 포함되어 있던 필드 이벤트 보상 코드가 `_spawn_open_map_boss()`에 놓여, 해당 함수에 없는 `difficulty`, `kill_reward_gold`, `kill_reward_xp`, `equipment_drops`를 참조했다. 이 때문에 세로형 시작 씬의 Main 상속 로드가 실패했다.

이 블록을 1회 보상 가드가 있는 `_finish_hunt_target()`의 실제 조우 정산으로 옮겼다. 보물 보상의 의도된 수치·확정 드롭 규칙을 지우거나 새 값을 넣지 않았다. 보스 등장만으로 보물을 지급하지 않고 무리 격파 시 한 번 처리한다. 세로형 화면의 기존 보스 메뉴 방식과 자동 지갑 수령 동작도 유지했다.

### 2. 영웅 상세·성장 화면의 타입 추론 오류

`PortraitPages.gd`의 `deployed_text`와 `state_text`에 명시적인 String 타입을 지정했다. 동적 main 호출 때문에 엔진이 타입을 추론하지 못하던 오류이며, 화면 레이아웃·그림·문구 자체는 새로 디자인하지 않았다.

### 3. 기존 레이드 테스트의 누락된 실행

`V74BossRaidBehaviorSmokeTest.gd`의 위치값 4개를 Vector2로 명시했다. 이어서 비동기 검사 2개의 호출에 await를 추가했다. 수정 전에는 25개 조건 뒤에 끝나 타깃 성향·역할 배치 검사가 완료되지 않았으나, 수정 후에는 **34개 조건을 끝까지 실행해 통과**했다. 게임의 레이드 수치·행동 코드는 바꾸지 않았다.

### 4. 재발 방지 및 결과 판정

`V80EngineRewardRegressionSmokeTest.gd`를 추가해 보스 등장 보상 중립성, 보물 정산 1회 지급, 중복 호출 방지, 영웅 상세·성장 화면 열기를 검사했다. **이 새 보상 검사에는 패배 처리된 무리를 직접 설정하는 단위 검사 픽스처가 들어 있으며, 실제 AI 전투 완주 검사로 세지 않는다.**

결과 도구는 실패 목록 `failures=[]`와 개수 `failures=0`, 레거시 `0 failures`를 모두 해석한다. 빈 목록 하나로 다른 실패가 가려지지 않게 했다. 이 도구의 Python 단위 검사 **13/13개**도 실행 통과했다. Python 검사는 아래 16개 Godot 실행 검사와 별개다.

## 최종 실제 엔진 검사

| 테스트 스크립트 | 결과 | 확인 조건 수 |
|---|---|---:|
| `V80ChallengeSessionSmokeTest.gd` | 통과 | 45 |
| `V80DailyBattleSmokeTest.gd` | 통과 | 18 |
| `V80DailyModesSmokeTest.gd` | 통과 | 109 |
| `V80DailySweepSmokeTest.gd` | 통과 | 35 |
| `V80DailyModesBattleSmokeTest.gd` | 통과 | 30 |
| `V80TowerRulesSmokeTest.gd` | 통과 | 451 |
| `V80TowerSettlementSmokeTest.gd` | 통과 | 50 |
| `V80TowerBattleSmokeTest.gd` | 통과 | 42 |
| `V80AbyssRulesSmokeTest.gd` | 통과 | 59 |
| `V80AbyssSettlementSmokeTest.gd` | 통과 | 57 |
| `V80AbyssSaveSmokeTest.gd` | 통과 | 15 |
| `V80AbyssBattleSmokeTest.gd` | 통과 | 16 |
| `V80EngineRewardRegressionSmokeTest.gd` | 통과 | 12 |
| `V74BossRaidBehaviorSmokeTest.gd` | 통과 | 34 |
| `V78ConvenienceUiSmokeTest.gd` | 통과 | 23 |
| `V79ConvenienceFlowSmokeTest.gd` | 통과 | 17 |

위 16개는 기존 v80 핵심 12개 + 이번 보상 회귀 검사 1개 + 기존 레이드/UI 회귀 3개다. **프로젝트에 등록된 148개 과거 SmokeTest를 전부 실행했다는 뜻은 아니다.**

### 실제 AI 전투 시나리오

- 일일 기본 골드 러시: 레벨 20의 3영웅 파티로 입장→기존 이동/공격/스킬→완료→보상 정산. 취소·전멸은 별도 실패 분기도 검사한다.
- 일일 3종: 레벨 60의 3영웅 파티로 골드 러시·60초 생존·보스 토벌을 각각 실행. 직접 클리어 해금과 다음 단계 소탕 잠금, 일반 사냥 보상 혼입 방지를 확인했다.
- 무한탑: 같은 레벨 60 파티로 1·5·6층을 실제 전투 실행. 5층 보스 출현, 필요한 모든 무리, 승리 후 층/보상 1회 갱신을 확인했다.
- 주간 심연: 90 게임 내 전투 초를 기존 AI로 진행하고 실제 HP 감소량과 기록 점수의 일치를 확인했다. 과잉 피해·저장 이전·중복 정산 등은 별도 규칙/정산/저장 테스트도 실행했다.

이 전투들은 엔진 안에서 기존 전투 업데이트 함수를 시뮬레이션 시간으로 호출한다. 성공 전투에서 적 HP를 강제로 0으로 하거나 제한시간을 줄여 성공시키지 않았다. 현실 시간 90초 영상·터치 플레이 검증을 뜻하지 않는다.

## 보존 확인

그래픽 에셋 **602개 전부 SHA-256 동일**. HeroRosterCatalog, EquipmentRules, GuardianCatalog, RaidBossDesign, RaidBattlefield, SaveStore, SaveValidation, 일일/탑/심연 전투 규칙, project.godot은 입력 v80-4와 동일하다. 저장 버전은 **34 유지**이며 이번에 새 저장 형식을 추가하지 않았다. 사용자 실제 저장 파일이 아닌 격리된 테스트 저장 공간을 사용했다.

## 아직 검증하지 않은 것

Android APK 내보내기·실기기 설치·FPS·발열·배터리·터치·실제 GPU 화면과 사운드 출력은 검사하지 않았다. 모든 영웅/진영·최대 10인 조합·신규 유저 난이도·탑 전 층·장시간 플레이도 이 집중 검사로 보증하지 않는다. Headless 성공을 상용 출시 품질이나 전체 게임 무결성으로 확대하지 않는다.

## 재현

```sh
python3 tools/run_v80_runtime_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output checks/runtime.json
# 위 명령은 v80 집중 13개. 전체 16개 결과에는 아래 기존 3종도 포함됨.
godot --headless --path /path/to/isolated/project --script res://tests/regression/V74BossRaidBehaviorSmokeTest.gd
godot --headless --path /path/to/isolated/project --script res://tests/regression/V78ConvenienceUiSmokeTest.gd
godot --headless --path /path/to/isolated/project --script res://tests/regression/V79ConvenienceFlowSmokeTest.gd
# 스크립트별 실제 엔진 검사 예시
godot --headless --path /path/to/isolated/project --check-only --script res://scripts/app/Main.gd
```

직접 명령은 복사본 및 격리된 XDG 저장 디렉터리에서 실행해야 한다. 기본 실행 도구는 임시 전체 프로젝트·고유 앱 이름·격리 저장을 자동 사용한다.

프로젝트의 `checks/runtime.json`, `checks/v80-5-compile.json`, `checks/v80-5-engine-summary.json`, `checks/v80-5-engine-logs/`에 결과와 로그를 보관했다. 새 배포 ZIP은 만들지 않았다. 다음 신규 개발 단계는 v81 장기 목표이며 아직 구현하지 않았다.

공식 옵션 참고: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
