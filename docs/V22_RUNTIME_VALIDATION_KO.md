# v22 실제 Godot 4.7.2 검증

- 엔진: Godot 4.7.2 stable official
- 에셋 import: 통과
- 메인 씬: headless 300프레임 실행, exit code 0
- 정적 검사: 통과
- Godot 4.7 호환성 스캔: 통과
- 전체 회귀 테스트: **46/46 PASS**
- 실패: 0

신규 `V22UiUpgradeSmokeTest.gd`는 다음을 검증합니다.
- 로비 대시보드
- 영웅 역할 필터와 정렬
- 전투 HUD 4칩
- 월드맵 대시보드
- 종의전쟁 지휘 대시보드
