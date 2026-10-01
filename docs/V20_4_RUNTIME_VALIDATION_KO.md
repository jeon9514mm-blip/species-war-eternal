# v20.4 Godot 4.7.2 실제 엔진 검증

v20.4는 사용자가 제공한 공식 `Godot_v4.7.2-stable_linux.x86_64` 실행파일로 실제 엔진 파싱과 headless 런타임 테스트를 수행한 수정본입니다.

## 실제 엔진에서 발견해 수정한 항목

- `WorldSupplyNetwork.is_connected()`가 Godot `Object.is_connected()`와 충돌하던 문제를 `is_supply_connected()`로 변경
- `WorldServerGateway.disconnect()`가 Godot `Object.disconnect()`와 충돌하던 문제를 `simulate_disconnect()`로 변경
- `WorldBattleResolver.gd`의 `role` 타입 추론 오류 수정
- `WorldWarScreen.gd`의 `distance` 타입 추론 오류 수정
- 이전 버전 Smoke Test들에 남아 있던 Godot 4.7 엄격 타입 추론 오류 정리
- 오래된 테스트가 현재 함수명/개별 HP 구조를 기대하지 못하던 부분 갱신
- 실시간 배회 사냥 회귀 테스트를 현재 v20 구조에 맞게 재작성

## 실제 실행 결과

- Godot 버전: `4.7.2.stable.official.ed1daf0bf`
- 프로젝트 import/parser: PASS
- 메인 씬 headless 300프레임: PASS, 종료 코드 0
- Smoke Test: 44/44 PASS
- AutoHuntRegressionTest: PASS
- 전체 런타임 테스트: **45/45 PASS**
- 정적 리소스/링크 검사: PASS
- Godot 4.7 호환성 스캔: PASS

## 자동사냥 회귀 검증 항목

- 실시간 필드 배회
- 고정 스폰 타깃 의존 제거
- 몬스터 전투 데이터와 필드 위치 동기화
- 일시정지 시 이동/타이머/보상 정지
- 재개 후 진행 복구
- 전멸 시 회복 모드 진입/자동 복귀
- 회복 중 보상 획득 방지
- 결정론적 근접 교전과 처치
- 처치 보상 중복 지급 방지
- 힐러의 부상 아군 반응
- 탱커 가드 피해 감소와 정상 만료

## 참고

Godot `.uid` 파일은 4.7.2 실제 import 과정에서 생성된 정상 리소스 UID 파일이므로 프로젝트에 포함합니다. `.godot` import/cache 폴더는 ZIP에서 제외합니다.
