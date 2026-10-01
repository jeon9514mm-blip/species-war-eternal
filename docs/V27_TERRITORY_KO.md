# V27 종의전쟁 / 영토전 마감 기록

검증 범위는 현재 게임의 로컬 권한 서비스와 비동기 전투 프로토타입이다. 실제 멀티플레이 서버 운영 완성도를 백분율로 환산하지 않는다.

## 완료 기준과 구현

| 기준 | 구현 및 검증 결과 |
|---|---|
| 명령을 재전송해도 한 번만 소비 | 행군/취소/보상 재전송 시 중복 군량 차감·환급·지급 방지. 같은 ID로 다른 목표를 보낸 경우 거절. 재시작 뒤 클라이언트 ID 충돌 방지 |
| 주둔이 원자적으로 이동 | 목적지 한도 검사 후 기존 부대 제거. 재등록은 성공 응답만 반환하고 공헌을 반복 지급하지 않음. 부대·타일별 지원 공헌 이력 저장 |
| 행군 출발부터 복귀까지 연결 | 실제 출발 경로/군량을 UI에 반환. 행군 중 이중 주둔 금지. 경로가 끊기거나 지원 목적지가 가득 찬 경우 원위치 복귀. 원위치까지 소실되면 수도로 대피 |
| 공방 결과와 부상 유지 | 수비 보너스가 매 공격마다 수비대를 완치시키던 오류 수정. 공격 피로·수비 버프는 전투 종료 후 기본 능력치로 환산하며 부상은 유지. 원정 부상은 파티 재등록·저장 후에도 유지되고 수도 귀환으로 회복 |
| 전선 보급과 자원 생산 연결 | 수도 군량 2/분, 광산 5/분, 마력숲 8/분, 유적 명예 1/분. 열세 진영 자원 배율 적용. 고립 자원 거점 생산은 25%. 명예 50을 군량 200으로 교환 |
| 시간 경과와 오프라인 중복 안전 | 자원 생산 최대 8시간, 잔여 소수와 마지막 계산 시각 저장. 역행한 시계로 중복 생산하지 않음. 시즌 종료를 걸친 오프라인 구간은 활동 종료 시점까지만 정산 |
| 시즌 정산 / 보상 / 재시작 | 시즌 공헌이 있는 플레이어의 정산 보상 한 번 지급·영수증 저장. 미수령 보상이 있으면 다음 시즌 시작을 잠금. UI에서 수령 및 다음 시즌 진행. 영토·군량·피로 초기화, 전쟁 명예 유지 |
| 상태 복원과 화면 연결 | 서명 없는 스냅샷 거절. 행군 경로·좌표·행동, 월드 400개 타일, 중첩 주둔·집결·대기열·숫자 데이터를 검증해 복원. 시즌 시간 역행 재개방 방지. 연결 실패 시 행군 요청 재시도 간격 적용 |

시즌 참여 보상은 군량 `200 + min(800, 공헌 × 2)`, 명예 `50 + min(500, 공헌) + 승리 100 또는 동률 50`이다. 군량은 전쟁용 소모품으로 다음 시즌 시작 시 초기화되며 명예는 계승된다. 전쟁 명예와 기존 PvE 성장 재화는 별도로 보관한다.

## 검증 증거

Godot 4.7.2 headless로 다음 **15개 테스트 스크립트가 모두 종료 코드 0, SCRIPT ERROR/ERROR 없이 통과**했다. 사용자 저장 데이터와 분리된 XDG_DATA_HOME에서 실행했다.

- 신규 `V27TerritoryLifecycleSmokeTest.gd`: **64개 assertion**. 양 진영의 중립 개척→실제 적 전투→점령·부상·시즌 점수까지 포함한다.
- `WorldWarStateSmokeTest`, `WorldSeasonStateSmokeTest`, `WorldConflictStateSmokeTest`, `WorldBattleResolverSmokeTest`, `WorldMarchStateSmokeTest`, `WorldSupplyNetworkSmokeTest`.
- `V12WorldWarSmokeTest`, `V13WarSafetySmokeTest`, `V14AsyncPvpSmokeTest`, `V15FrontlineSmokeTest`.
- `V16AuthoritySmokeTest`, `V16ClientSessionSmokeTest`, `V17ResyncServerTimeSmokeTest`, `V18SeasonSyncSmokeTest`.

재현:

```sh
Godot --headless --path . -s res://scripts/V27TerritoryLifecycleSmokeTest.gd
```

## 범위 밖과 남은 검증

- 실제 원격 서버 어댑터·계정 인증·공유 DB·여러 기기 간 원자성·운영 부하 검증은 미구현이다. 현재 로컬 권한 서비스는 보안 서버가 아니다.
- 시즌 장기 운영의 보상 수치와 명예 경제는 사용자 플레이 데이터를 바탕으로 추가 조정해야 한다.
- 화면 진입과 명령 연결은 기존 UI 회귀 테스트로 검증했다. Android 실기기의 터치·가독성 및 장시간 배터리/성능 검증은 별도 필요하다.
- 다른 영역과의 최종 전체 회귀 및 재실행 뒤 행군·주둔·시즌 보상 보존 결과는 [V27_CORE_SYSTEMS_KO.md](V27_CORE_SYSTEMS_KO.md)와 [V27_PERSISTENCE_INTEGRATION_KO.md](V27_PERSISTENCE_INTEGRATION_KO.md)를 따른다.

Main.gd는 수정하지 않았으며 기존 state_changed→전체 저장 연결을 사용한다.
