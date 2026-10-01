# v19 검증 상태

- Godot 기준: 4.7 / GL Compatibility
- 권장: Godot 4.7.2-stable
- save_version: 19
- 정적 검사 통과
- Godot 4.7 호환성 스캔 통과
- GDScript 중복 함수 / 기본 구문 균형 검사 통과

신규 스모크 테스트:
- `HeroIdentityBalanceSmokeTest.gd`
  - 양 진영 10인 평균 전투 예산 차이 3% 이내
  - 영웅별 예산 상·하한
  - 모든 영웅 AI 정체성 존재
- `V19HeroAIIdentitySmokeTest.gd`
  - 수호/처형 AI 스타일
  - 탱커/딜러 생존력 차이
  - 지원 영웅 궁극기 충전 특성
  - 월드전 snapshot에 identity 반영
- `V19ServerStabilitySmokeTest.gd`
  - stale snapshot 차단
  - 서버 시간 완만 보정
  - heartbeat revision 자동 resync
  - 재연결 시 최신 snapshot 사용
  - idempotency cache 상한

현재 작업 환경에는 Godot 4.7.2 실행파일이 없으므로 네이티브 headless 실행은 미검증입니다.
