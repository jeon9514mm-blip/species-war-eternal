# v16 서버 권한형 종의전쟁

v16은 v15의 전선 기능을 실제 온라인 서버로 옮기기 쉬운 구조로 분리한 버전입니다.

## 핵심 구조
- `WorldAuthorityService.gd`: 서버가 신뢰하는 부대 스냅샷, 명령 검증, revision/idempotency, 행군 도착, 공격/집결 결과를 권한적으로 처리
- `WorldServerGateway.gd`: 현재 로컬 권한 서버와 미래 원격 전송 사이의 게이트웨이
- `WorldWarClientSession.gd`: 전쟁 UI가 서버 명령을 보내고 revision을 동기화하는 클라이언트 세션
- `WorldConflictState.gd`: 다중 수비대, 공격 큐, 집결 상태
- `WorldSupplyNetwork.gd`: 수도 보급망과 고립 영토
- `WorldBattleResolver.gd`: 결정론적 10vs10 계산

## 중요한 개선
1. 클라이언트가 보낸 영웅 공격력/HP를 전쟁 판정에 그대로 신뢰하지 않습니다.
2. 권한 서비스에 등록된 trusted party snapshot을 사용합니다.
3. 같은 command ID가 재전송되어도 군량이나 전쟁 상태가 이중 반영되지 않도록 idempotency를 둡니다.
4. stale world revision 명령을 거부합니다.
5. 등록되지 않은 player ID의 명령을 거부합니다.
6. 행군 도착/점령/주둔도 ClientSession → Gateway → Authority 흐름으로 처리합니다.
7. 실제 원격 서버가 아직 없을 때는 로컬 authoritative gateway로 동작합니다.

## 현재 한계
이 버전은 서버 '프로토콜과 권한 경계'를 만드는 단계입니다. 실제 인터넷 백엔드, 계정 인증 서버, DB, WebSocket/HTTPS 전송은 포함하지 않습니다. 온라인 출시에서는 Authority/Gateway의 서버 측 구현을 별도 백엔드로 옮겨야 합니다.

## 다음 단계
v17에서는 네트워크 DTO, 서버 응답 스냅샷 적용, 재접속/재동기화, 서버 시간 오프셋, 충돌 복구를 강화하는 방향이 적합합니다.
