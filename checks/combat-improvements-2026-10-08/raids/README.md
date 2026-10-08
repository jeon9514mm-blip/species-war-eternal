# 레이드 전용 맵 검수

실제 `PortraitMain → RaidPresentationV2 → RaidArenaBattlefield`에서 촬영한 Godot Mobile 화면입니다. 원화 배우와 기존 전투 규칙을 유지하면서 보스별 정적 3D 무대와 PBR 바닥을 제작했습니다.

| 전용 맵 | 실제 화면 | 차별 요소 |
| --- | --- | --- |
| 천공 수호 유적 | [준비](gray_meadow-ready.png) · [전투](gray_meadow-running.png) | 청동 석판 경계, 청록빛 신단, 풍화된 쌍열주 |
| 호박빛 심층 광산 | [준비](forgotten_mine-ready.png) · [전투](forgotten_mine-running.png) | 호박 광맥, 광산 지지대와 높은 가로대, 외곽 운반 레일 |
| 월광의 성소 | [준비](moonrest_forest-ready.png) · [전투](moonrest_forest-running.png) · [960×540](moonrest_forest-small.png) | 자주빛 석판, 초승달 신단, 수정 기둥 |

## 수정한 문제

- 이전 레이드 GLB의 소품은 일반 사냥터 좌표를 기준으로 배치되어 있었습니다. 레이드의 가로로 펼친 실제 `RaidBattlefield.FLOOR` 안에 기둥과 바위가 들어오는 부분을 확인했습니다. 해당 소품의 표시를 대체하고 전용 건축은 실제 이동 영역 밖에 배치했습니다.
- 각 맵의 전투 구역은 긴 석판, 그라우트, 모서리 마모, 금속 세공으로 구분하고 외곽을 어둡게 낮췄습니다. 실제 전투 바닥의 높이는 `y = 0`이며 맵 제작은 기존 좌표 변환을 사용합니다. 최종 통합에서는 별도로 레이드의 안정된 카메라·간격 환산·보간을 수정했고, 이 화면 7장은 해당 최종 소스로 다시 촬영했습니다.
- 초기 native 검수에서 단색 건축과 광산 가로대가 영웅 머리선에 겹치는 것을 발견했습니다. 기존 stone 1024 albedo/normal을 건축에 재사용하고, 가로대를 뒤쪽으로 옮겨 높은 위치에 배치한 뒤 7장을 다시 촬영했습니다.

## 비용과 보존

- 전용 무대는 맵마다 최대 45개 정적 메시이며 추가 동적 조명은 0개, 건축 그림자 추가 패스는 0개입니다. 기존 공유 태양과 PBR 재질을 사용합니다.
- 기존 4종 packed stone 텍스처를 재사용합니다. 새 대용량 텍스처는 추가하지 않았습니다. 바닥의 parallax는 balanced 4단계, quality 8단계를 유지합니다.
- 보스와 영웅의 원화, 원정대 상태, 공격 판정, HP, 쿨다운, 보상, 게임 RNG는 맵 제작 코드가 변경하지 않습니다.
- 캡처는 플레이어 세이브를 읽지 않는 격리된 검수 데이터입니다. Stage154/영웅 Lv60 10명, 실제 레이드 0.60초 진행 상태이며 이 화면에서는 효과와 소리만 껐습니다. 게임 기본 설정은 바꾸지 않았습니다.
- 이 자료는 UI/맵 검수이며 **FPS 측정 자료는 아닙니다**.

## 검증

[최종 회귀검사](regression-validation.json)는 아래 5개 모두 통과했습니다. 합계 2,496개 조건입니다.

| 검사 | 조건 수 | 확인 범위 |
| --- | ---: | --- |
| RaidDedicatedArenaSmokeTest | 264 | 3종의 실제 전용 메시/바닥, 품질 전환, 정적 비용, 이동 영역·역투영·게임 상태 보존 |
| RaidTouchLayoutSmokeTest | 1,044 | 3보스/2진영/여러 창 크기, 실제 터치·이동·회피·선택, HUD와 전투 영역 분리 |
| RaidBossPaintFramingSmokeTest | 681 | 원화의 무기/날개/머리까지 전체 보스 프레임 여유 |
| RaidDesignSmokeTest | 486 | 전용 실전 경로, 경고와 판정 일치, 멈춤/재시도/저장 미사용 |
| FinalEnvironmentSmokeTest | 21 | 기존 1024 PBR/레이드 원형/조명/정지·효과 끄기 보존 |

첫 실행의 `RaidDesignSmokeTest`는 테스트가 요구하는 `art-pilot-raid-validation` 격리 경로 문자열을 runner가 사용하지 않아 자체 저장 보호 가드에서 거부되었습니다. [최초 기록](regression-initial-validation.json)을 보존했습니다. 테스트별 새로운 사용자 디렉터리와 올바른 경로를 적용한 뒤 다시 실행한 최종 결과는 모두 통과했습니다. 이후 통합 변경은 [최종 Mobile 회귀](../../hunt-raid-improvements-2026-10-08/delivery-validation.json)에서 전용 무대·보스 원화·레이드 이동·보간을 재검증했습니다.

[native 캡처 검증](capture-validation.json) · [검수 상태](capture-fixture.json) · [소스·화면 SHA256](source-hashes.json)

재현: `tools/diagnostics/combat-improvements-2026-10-08/run_raid_review.py --tests-only` 또는 `--capture-only`. native GPU 캡처/성능 측정은 다른 native 실행과 동시에 하지 않습니다.
