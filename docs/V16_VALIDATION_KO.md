# v16 검증 상태

- Godot 기준: 4.7 / GL Compatibility
- 권장 실행: Godot 4.7.2-stable
- 저장 버전: 16
- 정적 검사: 통과
- Godot 4.7 호환성 소스 스캔: 통과
- GDScript 50개 / Smoke Test 32개

v16 신규 검증에는 `V16AuthoritySmokeTest.gd`와 `V16ClientSessionSmokeTest.gd`가 포함됩니다. 명령 revision, 중복 명령 idempotency, 미등록 플레이어 거부, 서버 신뢰 영웅 스냅샷, 행군 도착/주둔과 client revision 동기화를 검사하도록 구성되어 있습니다.

현재 작업 컨테이너에는 Godot 4.7.2 네이티브 실행파일이 없어 실제 엔진 headless 테스트는 실행하지 못했습니다. PC의 Godot 4.7.2에서 `tools/run_tests.py`로 전체 스모크 테스트를 실행할 수 있습니다.
