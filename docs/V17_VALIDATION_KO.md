# v17 검증 상태

## 기준

- Godot 프로젝트 기능 버전: 4.7
- 권장 실행 환경: Godot 4.7 계열
- GL Compatibility
- 저장 버전: 17

## 정적 검증

- GDScript 파일/리소스/README 링크 검사: 통과
- Godot 4.7 마이그레이션 API 검사: 통과
- 중복 함수 검사: 통과
- 잘못 삽입된 literal `\\t` 검사: 통과
- save_version 17 확인

## 신규 스모크 테스트

### IdleHuntEstimatorSmokeTest.gd

- 1인 약한 파티도 방치 진행 가능
- 강한 다인 파티의 오프라인 효율 증가
- 오프라인 스테이지 진행 상한
- 장비 RNG 재생 상한
- 빈 파티 보상 차단

### V17HuntProgressionSmokeTest.gd

- 회복 후퇴와 길찾기 실패 점수 분리
- 장시간 이동 정체 재탐색
- 편성 한도 1→3→5→7→10
- 기존 v16 편성 마이그레이션 보호

### V17ResyncServerTimeSmokeTest.gd

- 최초 authoritative snapshot 동기화
- 서버시간 행군 시작/도착 시각
- 연결 끊김 후 cached snapshot 복원
- 서버시간 경과 후 행군 도착/중립 점령
- stale revision 자동 resync

## 런타임 제한

현재 작업 컨테이너에는 Godot 네이티브 실행파일이 설치되어 있지 않아 실제 Godot 4.7 엔진 headless 실행은 수행하지 못했습니다.

Godot이 설치된 환경에서는 프로젝트의 `tools/run_tests.py`로 스모크 테스트를 실행할 수 있습니다.
