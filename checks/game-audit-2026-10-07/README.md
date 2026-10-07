# 전체 점검·개선 기록 — 2026-10-08

기준 코드 0b559b37c7bf95da2a17897227b2ddb7867a9202. 실제 사용자 저장 대신 임시 APPDATA/XDG로 실행했습니다. 사용자 요청의 10개 그래픽/움직임 사양을 적용하며 전투·화면·보상·저장·성능·과거 회귀를 함께 점검했습니다. [최신 사양/화면/영상](../mobile25d-spec-2026-10-07/README.md).

## 발견 후 수정

| 문제 | 수정·근거 |
|---|---|
| 사냥 숫자의 낮은 표시 순서와 조기 퇴장 | 숫자z105/보상z106, 잘못 병렬 연결된 hold/퇴장을 .32+.28=.60초로 수정. 실제 GPU 숫자와 .39/.59/.61초 수명 검사 통과 |
| 카메라 호흡/줌과 레이드 터치 좌표 불일치 | 카메라의 실제 역투영으로 이동 명령 변환, 경고/선택/2D arena도 매 프레임 같은 투영. RaidDesign/RaidTouch 통과 |
| 큰 보스 머리와 영웅 추격이 화면 경계를 넘음 | 보스 머리/바닥/컨텍스트 여백 동시 보정. 영웅 세로 추격1.85로 제한, 크기86.4 유지. StableFacing 통과 |
| 전장 외곽의 빈 배경과 바닥 중복 그리기 | PBR 석판 plane80×60, 숨겨진 이전 바닥 draw 제거. 석재 UV 밀도 유지 |
| 동일 atlas의 공격/대기에서 털이 이전 cell을 사용 | atlas 경로 대신 실제 cell region으로 캐시. 16몬스터/보스의 실제 메시/털/공유 텍스처 검사 |
| 불필요한 대형 기존 텍스처 상시 로드 | 기존 영웅6boards/몬스터sheets를 요청 시 로드. 같은 GPU 측정의 약188MB→112MB |
| CPU 위치 계획/경로/공격 검사 반복 | 위치계획.10–.12초, exact segment cache+AABB broadphase, 타깃 단건 검사, body solve8회+기존 rescue. 동일360스텝 진단에서35.10→19.94ms/step. 실제 독립 교전/유효 이동 회귀 통과 |
| 일반 사냥의 프레임당 계산 부담 | 전경 시뮬레이션 누적 시간20Hz. 렌더/입력은 계속 갱신. 최대50ms 판정 간격은 명시적 동작 변경 |
| 순식간에 종료하는 검사 audio 정리 누락 | BM fixture audio shutdown/정리 대기. 재검사 통과. 다른 오래된 fixture의 종료 누수는 통과로 바꾸지 않음 |
| multipart 검사 안전 경로 요구 불충족 | 격리 폴더 이름에 art-pilot 포함. 이후 오래된 observe_game/hold_demo API 의존은 별도 미해결 |

## 성능과 남은 우선순위

GTX1050/Windows, Mobile, 효과 켜짐. Android 실기기는 측정하지 않았습니다. **60fps 미달**입니다. [원본 측정 JSON](../mobile25d-spec-2026-10-07/review-mobile/performance.json).

| 프로필 | 평균fps | p95 frame ms | texture memory | 살아있는 일반 적 |
|---|---|---|---|---|
| hunt-balanced | 35.45 | 54.88 | 111.9 MB | 19 |
| hunt-battery | 26.56 | 60.66 | 95.9 MB | 18 |
| raid-balanced | 54.69 | 47.20 | 105.3 MB | 0 |

1. 화면 품질: 참고 이미지와 비교한 원화 명암·발광 문양·보상 광기둥의 밀도/재질 조화. 수치 적용을 시각 품질 달성으로 대신하지 않음.
2. 성능: CPU simulation spike와 약500 draw calls 줄이기. Forward+ SDFGI의 추가 메모리는 Mobile 예산에 포함하지 않음. 실제 휴대폰의 GPU/발열/배터리와 장시간 측정 필요.
3. 검사 유지: 구세대 세로 UI, 장애물17개, 이전 atlas/스켈레톤, 삭제한 스킬 VFX, 고정 world height를 전제로 한 검사와 현재 사양을 대조. 검사 삭제나 임의 완화로 통과시키지 않음.
4. 경제/전투 후보: forest 장기 clear, offline reward fixture, field save barrier, dead-boss callbacks의 실패 원인을 최신 실제 플레이 경로에서 추가 재현. 이번 변경만의 신규 버그라고 단정하지 않음. Ledger/GameplayReliability/도전·보상 관련 현재 검사 통과 기록도 함께 보존.

## 검증과 한계

전체234개 실행: 최초 152/234 통과. 이후 집중 재검사 파일은 summary.json에 기록하며 해당 이름의 결과만 갱신합니다. 최신 확인 결과는 **157/234**, 전부 통과한 상태가 아닙니다. Python50/50·static/resources/architecture 통과. 초기 구문508/509 중 LandingScreens 엔진 프로세스 종료는 단독 재검사 통과했으며 변경 소스는 별도 최종 검사 기록에 남깁니다.

[전체 실행 원본](all-runtime-regressions-final.json), [전체 구문 원본](all-regressions-final.json), [이전 커밋에서 재현 비교](baseline-comparison.json), [요약](summary.json). 원본 비교는 이전 커밋의 코드/검사와 변경되지 않은 기존 에셋·import cache를 사용했습니다. 신규 mobile 에셋은 이전 코드에서 참조하지 않습니다.

실제 GPU 관찰: UI 25화면, 양 진영10인 사냥600표본, 레이드59표본. **영웅 몸체 겹침 표본 0건**. 무기/털/공격 원화의 투명 외곽 접촉은 몸체 판정과 다릅니다. 30초 관찰을 모든 조건의 무겹침 보장으로 표시하지 않습니다. 버튼 사각형 교차는 스크롤/부모/모달의 의도된 겹침도 포함하므로 자동 검출만으로 UI 버그라 하지 않습니다.

## 남은 실패 목록

| 검사 | 이전 코드 비교 | 최초 오류/상태 |
|---|---|---|
| AureliaHeroPartsSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: diagnostic requires an isolated art-pilot XDG_DATA_HOME |
| AutoHuntRegressionTest.gd | 원본에서도 실패 확인 | ERROR: Roaming party did not move; ERROR: Lethal hit allowed retaliation or did not credit each defeated pack once; ERROR: 2 resources still in use at exit (run with --verbose for details). |
| BossEncounterSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 3 resources still in use at exit (run with --verbose for details). |
| CombatQualitySmokeTest.gd | 원본에서도 실패 확인 | ERROR: initial heroes spaced; ERROR: initial heroes spaced; ERROR: initial heroes spaced |
| FirstSessionEconomySmokeTest.gd | 원본에서도 실패 확인 | 시간 초과 |
| HeroSkeletalRigSmokeTest.gd | 원본에서도 실패 확인 | ERROR: actual hunt renderer skins every deployed hero; ERROR: actual raid renderer skins every deployed hero |
| IdleSmokeTest.gd | 원본에서도 실패 확인 | ERROR: Offline idle reward did not arrive; ERROR: Idle stage chest did not unlock; ERROR: Idle reward claim failed |
| LandscapeRosterUiSmokeTest.gd | 원본에서도 실패 확인 | ERROR: V56 dungeon/roster UI: empty first-run formation PortraitMenuBack ‹ full button caption; ERROR: V56 dungeon/roster UI: one hero with locked slots PortraitMenuBack ‹ full button captio |
| LevelSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| MapTerrainSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 3 resources still in use at exit (run with --verbose for details). |
| MeadowAppliedSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| PortraitRegressionSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: project locks portrait orientation; ERROR: combat field truly portrait, not a letterboxed landscape canvas; ERROR: ten visible hero/locked slots |
| QualityV40SmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| RaidCatalogUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: raid UI control exists PortraitMenuBack; ERROR: return from gray_meadow retains the raid content tab; ERROR: return from gray_meadow shows three bosses in one row |
| RaidSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Raid clear was not recorded; ERROR: Raid reward or stop state failed; SCRIPT ERROR: Invalid access to property or key 'forgotten_mine' on a base object of type 'Dictionary'. |
| SmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 3 resources still in use at exit (run with --verbose for details). |
| UnifiedInterfaceSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V10UiUxSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V10: 장착장비 일괄강화 실패; ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V12WorldWarSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V17HuntProgressionSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V19HeroAIIdentitySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V20RealtimeRoamingHuntSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V20: 자동사냥 중 원정대가 이동하지 않음; ERROR: 2 resources still in use at exit (run with --verbose for details). |
| V22UiUpgradeSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V25CombatFxSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V25: 범위공격 인디케이터 생성 실패 |
| V26ActionSafetySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | V26 ACTION FAIL: basic windup retargets a living reachable enemy; V26 ACTION FAIL: skill windup retargets a living reachable enemy; V26 ACTION FAIL: retargeted skill consumes cooldown only a |
| V26CombatDecisionSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | V26 FAIL: out-of-range front hero does not starve ready ranged ally; V26 FAIL: melee damages adjacent enemy despite distant front row; ERROR: v26_combat_decision_smoke_test_failed checks=14  |
| V27BalanceMatrixSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | V27 BALANCE FAIL: aurelia/moonrest_forest/3/Lv10/seed2701: at least one full encounter completes; V27 BALANCE FAIL: noxfera/forgotten_mine/10/Lv10/seed2701: at least one full encounter compl |
| V27BossLifecycleSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Later heroes do not spend ultimate on dead boss |
| V27CombatClockSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V27FieldLifecycleSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Spawned ecology reaches combat data; ERROR: Spawned ecology reaches combat data; ERROR: Spawned ecology reaches combat data |
| V27GrowthEconomySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V27 growth: full bag preserves stronger enhanced gear and salvages weaker arrival |
| V27HeroRolesSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 2 resources still in use at exit (run with --verbose for details). |
| V27PersistenceIntegrationSmokeTest.gd | 원본에서도 실패 확인 | V27 PERSISTENCE FAIL: offline estimate grants resources and commits the consumed time interval; ERROR: v27_persistence_integration_smoke_test_failed checks=18 failures=1: offline estimate gr |
| V27RaidIntegrationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V28BrightUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 2 resources still in use at exit (run with --verbose for details). |
| V28KitingRegressionSmokeTest.gd | 원본에서도 실패 확인 | V27 BALANCE FAIL: aurelia/moonrest_forest/3/Lv10/seed2701: at least one full encounter completes; V27 BALANCE FAIL: noxfera/moonrest_forest/3/Lv10/seed2701: at least one full encounter compl |
| V28MeadowNavigationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Sealed northeast corner cannot trap a new spawn; ERROR: Observed combat position inside the eastern tree is blocked; ERROR: Eastern canopy center from the captured world position is b |
| V28MovingHuntSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: No hero teleports between packs; ERROR: 2 resources still in use at exit (run with --verbose for details). |
| V29BoundarySpawnSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Sealed eastern tree pocket is not connected to the hunting field |
| V29FactionBalanceSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V30UiFlowSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: device login callback opens the lobby; ERROR: new player's lobby exposes party creation; ERROR: navigation action exists: 장비 |
| V32GraphicsSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: gray_meadow loads its upgraded world texture; ERROR: forgotten_mine loads its upgraded world texture; ERROR: forgotten_mine has unique environment artwork |
| V46FactionIsolationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V46StabilitySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V47NavigationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: target ranking accounts for the pond detour; ERROR: hero prefers the reachable target; ERROR: party anchor uses the same terrain-aware choice |
| V47PortraitSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V48WarUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V48 UI: panel fits portrait WarCommandPanel (720, 1280); ERROR: V48 UI: commands clear the navigation (720, 1280); ERROR: V48 UI: territory details retain readable scroll area (720, 1 |
| V49PortraitLayoutSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V49 layout: aurelia (720, 1280) _build_login_screen · ‹ button caption visible; ERROR: V49 layout: aurelia (720, 1280) _build_faction_screen · ‹ button caption visible; ERROR: V49 lay |
| V50CampaignUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V50 UI: text fits viewport: 현재 주둔 위치; ERROR: V50 UI: text fits viewport: 영토 정찰; ERROR: V50 UI: text fits viewport: 부대 지휘 ▴ |
| V51CombatSafetySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: aoe fixture triggers lethal Bron counter; ERROR: aoe counter-killed boss remains dead; ERROR: aoe counter damage settles once without overkill credit |
| V51PersistenceLifecycleSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V51 persistence: startup settlement keeps the title screen |
| V51SessionIntegritySmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V52HuntIntegrationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | V52 HUNT INTEGRATION FAIL: aurelia/moonrest_forest/10: solo first corps clears in two minutes; larger parties sustain repeated clears; V52 HUNT INTEGRATION FAIL: noxfera/moonrest_forest/10:  |
| V52HuntUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V52 hunt UI: party strip remains one row for every party size; ERROR: V52 hunt UI: party camera remains clear of bottom controls; ERROR: V52 hunt UI: at least 700 logical pixels of cl |
| V52PopulationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Live habitat uses expanded population aurelia/1; ERROR: Live habitat uses expanded population aurelia/10; ERROR: Live habitat uses expanded population noxfera/1 |
| V53HuntFeedbackSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V53HuntSupportSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | SCRIPT ERROR: Invalid access to property or key 'elisia' on a base object of type 'Dictionary'.; SCRIPT ERROR: Invalid access to property or key 'elisia' on a base object of type 'Dictionary |
| V55EquipmentDetailUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V55 equipment detail: selected equipment information button caption visible EquipmentDetailBack; ERROR: V55 equipment detail: detail info (568, 320) button caption visible EquipmentDe |
| V56DungeonRosterUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V56 dungeon/roster UI: empty first-run formation PortraitMenuBack ‹ full button caption; ERROR: V56 dungeon/roster UI: one hero with locked slots PortraitMenuBack ‹ full button captio |
| V58ArtScrollSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V58 art/scroll: portrait hunt uses painted monster atlas; ERROR: V58 art/scroll: painted monster preserves action poses; ERROR: V58 art/scroll: portrait hunt uses painted monster atla |
| V59ThreeRaidVisualSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V5FoundationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Inventory overflow protection failed; ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V61FieldRolesMotionSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V62RigFxRewardSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V62 reward feed sits above combat buttons |
| V63AutoFxOfflineSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V63 separate auto buttons fit above hunt controls; ERROR: V63 reward feed leaves auto buttons unobstructed; ERROR: V63 online hunt credits currency and account XP without a claim |
| V65GuardianSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Guardian: offline hunt pays the guardian-adjusted gold and experience once |
| V66UiFilterSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
| V67FieldTerrainNavigationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: Meadow retains all seventeen legacy obstacles; ERROR: Zone-switch fixture populates all navigation caches; ERROR: Mine uses its own underground water collision |
| V6CombatSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: A full 10-person party should populate the denser v70 field |
| V78ConvenienceUiSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: V78 convenience UI: bag exposes at-a-glance capacity summary; ERROR: V78 convenience UI: recommend equip is a primary bag action; ERROR: V78 convenience UI: bag exposes grouped quick  |
| V82PresentationUiSmokeTest.gd | 원본에서도 실패 확인 | ERROR: new settings reachable without overcrowded fixed menu |
| V8362FieldSafetySmokeTest.gd | 원본에서도 실패 확인 | ERROR: corps reward save failure activates write barrier; ERROR: failed-save reward is not repeated and battle freezes; ERROR: reward snapshot retry succeeds |
| V8363IceVisualSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V8364CombatViewSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: consistent original hero body height after crowd fitting; ERROR: consistent original hero body height after crowd fitting; ERROR: consistent original hero body height after crowd fitt |
| V8364VisualSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | 시간 초과 |
| V83NavigationSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: catalog reads cannot corrupt canonical dock; ERROR: menu data independent; ERROR: active tab lobby |
| V8PolishSmokeTest.gd | 기대치/실행 경로 추가 재현 필요 | ERROR: 1 resources still in use at exit (run with --verbose for details). |
