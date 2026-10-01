# v20 검증 상태

- Godot 기준: 4.7 / GL Compatibility
- 권장 실행: Godot 4.7.2-stable
- save_version: 20
- 정적 검사 통과
- Godot 4.7 호환성 스캔 통과
- GDScript 중복 함수 / 기본 구문 균형 검사 통과

신규 테스트:
- `RoamingHuntDirectorSmokeTest.gd`
  - 파티 자유 순찰
  - 몬스터 배회
  - 감지
  - 추격
  - 교전 진입
  - 전멸 후 어그로 해제
- `V20RealtimeRoamingHuntSmokeTest.gd`
  - 실전 Main 전투 화면에서 배회 몬스터 생성
  - 파티/몬스터 동시 이동
  - 기존 고정 target_index 의존 제거
  - 몬스터 걷기/월드 좌표 API 확인

현재 작업 컨테이너에는 Godot 4.7.2 실행파일이 없어 실제 네이티브 headless 테스트는 실행하지 못했습니다.
