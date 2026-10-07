# v80-1 개발 진행 및 검증 기록

기준일: 2026-09-30  
상태: **개발 중(WIP). 정식 v80 완료본 또는 실행 검증 완료본이 아님.**  
기준: 대화에 첨부된 v79 전체 분할 압축 5개 파일. Library 체크섬 목록과 5개 모두 SHA-256 일치 확인 후 복원.

## 이번에 실제로 수정한 내용

- 일일 던전의 기존 `Main.gd._run_daily_dungeon()` 즉시 지급 경로를 실제 전투 진입으로 교체.
- `ChallengeBattleSession.gd`: 세션 ID, 제한시간, 무리 격파, 승리/실패/취소, 1회 보상 정산 상태 관리.
- `DailyDungeonBattleRules.gd`: 60초 내 3개 무리 격파 기본형. 각 무리 6마리. 적 능력치는 임시 튜닝 값이며 실제 난이도 검증이 필요함.
- `ChallengeBattleDirector.gd`: 기존 필드 이동, 역할 AI, 영웅 스킬, 수호신 전투 처리 재사용. 별도 전투력 수치로 자동 승리시키지 않음.
- 일반 사냥 보상/장비 드롭/군량/스테이지 상승을 던전의 중간 무리 처치에서 차단. 전체 승리 시에만 기존 일일 보상 정산.
- 승리 보상은 1/2/3회차 순서로 골드 950/1200/1450, 계정 및 영웅 경험치 350/450/550, 수호신 경험치 60을 유지.
- 실패/화면 이탈에는 완료 횟수나 보상을 늘리지 않음. 전체 전멸 시 일반 사냥의 자동 부활 경로를 사용하지 않음.
- 기존 세로형/레거시 던전 버튼에서 진입 직후 메뉴를 다시 열어 전투를 취소하던 연결 방식 수정.
- 기존 HUD의 텍스트와 진행바에 던전 목표/남은 시간 연결. 이미지·색상·레이아웃 교체 없음.
- 신규 GDScript 테스트 2개 작성, 즉시 보상을 전제로 하던 기존 테스트 4개를 실제 전투 결과 대기 방식으로 수정. **이 테스트들은 아직 실행하지 못함.**

## 실제 수행한 검사

### tools/static_validate.py

```text
STATIC VALIDATION OK | gd=245 smoke=137 resources=ok links=ok
```

### tools/godot47_compat_scan.py

```text
GODOT 4.7 COMPAT SCAN OK
```

### tools/validate_v80_daily_integration.py

```text
V80 SOURCE-STRUCTURE CHECKS OK | checks=21 | GDScript runtime NOT executed
```

위 `gd=245 smoke=137`은 스캔한 스크립트와 테스트 대상 수이다. **245개 GDScript 컴파일 통과 또는 137개 테스트 실행 통과를 뜻하지 않는다.** `godot47_compat_scan.py`도 특정 API 문자열만 점검하는 제한된 소스 검사이며 완전한 호환성 검증이 아니다.

`assets/` 아래 기존 파일 **602개**가 기준본과 동일함을 SHA-256으로 확인했다. 다음 핵심 파일 10개 및 주요 기존 함수 12개도 동일하다.

핵심 파일: `project.godot`, `scripts/heroes/HeroRosterCatalog.gd`, `scripts/heroes/HeroCombatRules.gd`, `scripts/heroes/HeroKitRuntime.gd`, `scripts/equipment/EquipmentRules.gd`, `scripts/heroes/GuardianCatalog.gd`, `scripts/persistence/SaveStore.gd`, `scripts/persistence/SaveValidation.gd`, `scripts/raid/RaidBossDesign.gd`, `scripts/raid/RaidBattlefield.gd`.

기존 함수: `_save_idle_state`, `_load_idle_state`, `_advance_roaming_hunt`, `_advance_hunt_attacks`, `_hero_combat_stats`, `_cast_combat_skill`, `_damage_enemy`, `_start_raid`, `_advance_raid_encounter`, `_finish_raid`, `_run_weekly_trial`, `_challenge_tower`.

## 아직 수행하지 못한 검증

- Godot 실행 파일이 현재 환경에서 확인되지 않았고, 공식 실행 파일 다운로드도 실패함.
- 실제 GDScript 파서/타입 검사, 신규·기존 게임 테스트 실행은 미수행.
- 실제 화면에서의 일일 던전 완주 가능성, 몬스터 배치/이동거리 대비 60초 난이도, UI 표시/터치/화면전환은 미검증.
- Android 설치·기기 FPS/발열·장시간 안정성은 미검증.
- 보상 가드는 로컬 코드의 중복 처리 방지이며 서버 권한 또는 조작 방지 보장을 뜻하지 않음.

## 남아 있는 v80 범위

1. 이번 일일 던전 기본형의 실제 실행 검증과 난이도 조정.
2. 골드 러시/생존/보스전 변형, 최초 클리어 기록 기반 소탕.
3. 무한탑의 실제 층별 전투 연결.
4. 주간 심연의 90초 실제 전투와 피해 점수/주간 효과 연결.

무한탑·주간 심연은 이번 수정에서 변경하지 않았다. 그래픽, 저장 스키마, 영웅/장비/수호신 데이터와 레이드 규칙도 변경하지 않았다. 새 배포 ZIP은 패키징하지 않았다.

## 수정 파일

- `scripts/ui/ContentScreens.gd`
- `scripts/app/Main.gd`
- `tests/regression/V51PersistenceLifecycleSmokeTest.gd`
- `tests/regression/V56DungeonRosterUiSmokeTest.gd`
- `tests/regression/V57QualityPassSmokeTest.gd`
- `tests/regression/V9MetaLoopSmokeTest.gd`
- `scripts/portrait/PortraitHud.gd`
- `scripts/portrait/PortraitPages.gd`

## 추가 파일

- `scripts/combat/ChallengeBattleDirector.gd`
- `scripts/combat/ChallengeBattleSession.gd`
- `scripts/progression/DailyDungeonBattleRules.gd`
- `tests/regression/V80ChallengeSessionSmokeTest.gd`
- `tests/regression/V80DailyBattleSmokeTest.gd`
- `tools/validate_v80_daily_integration.py`
